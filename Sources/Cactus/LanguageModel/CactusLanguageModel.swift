import CXXCactus
import Foundation

// MARK: - CactusLanguageModel

/// A language model powered by the cactus engine.
///
/// This class is largely not thread safe outside of calling ``stop()`` on a separate thread when
/// the model is in the process of generating a response.
///
/// All methods of this class are synchronous and blocking, and should not be called on the main
/// actor due to the long runtimes. To access the model safely in the background, you can create a
/// background actor to protect the model from data races.
/// ```swift
/// final actor LanguageModelActor {
///   let model: CactusLanguageModel
///
///   init(model: sending CactusLanguageModel) {
///     self.model = model
///   }
///
///   func withIsolation<T, E: Error>(
///     perform operation: (isolated LanguageModelActor) throws(E) -> sending T
///   ) throws(E) -> sending T {
///     try operation(self)
///   }
/// }
///
/// @concurrent
/// func chatInBackground(
///   with modelActor: LanguageModelActor
/// ) async throws {
///   try await modelActor.withIsolation { @Sendable modelActor in
///     // You can access the model directly because the closure
///     // is isolated to modelActor.
///     let model = modelActor.model
///
///     // ...
///   }
/// }
/// ```
public final class CactusLanguageModel {
  /// The ``Configuration`` for this model.
  public let configuration: Configuration

  /// The ``Properties`` for this model.
  public let properties: Properties

  /// The underlying model pointer.
  public let model: cactus_model_t

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - contextSize: The context size.
  ///   - modelSlug: The model slug.
  public convenience init(from url: URL, contextSize: Int = 2048, modelSlug: String? = nil) throws {
    let configuration = Configuration(modelURL: url, contextSize: contextSize, modelSlug: modelSlug)
    try self.init(configuration: configuration)
  }

  /// Loads a model from the specified ``Configuration``.
  ///
  /// - Parameter configuration: The ``Configuration``.
  public init(configuration: Configuration) throws {
    do {
      self.configuration = configuration
      let model = cactus_init(configuration.modelURL.nativePath, configuration.contextSize)
      guard let model else { throw ModelCreationError(configuration: configuration) }
      self.model = model
      self.properties = try Properties(
        contentsOf: configuration.modelURL.appendingPathComponent("config.txt")
      )
      CactusTelemetry.send(CactusTelemetry.LanguageModelInitEvent(configuration: configuration))
    } catch let error as ModelCreationError {
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "init",
          message: error.message,
          configuration: configuration
        )
      )
      throw error
    }
  }

  deinit { cactus_destroy(self.model) }
}

// MARK: - Configuration

extension CactusLanguageModel {
  /// A configuration for loading a ``CactusLanguageModel``.
  public struct Configuration: Hashable, Sendable {
    /// The local `URL` of the model.
    public var modelURL: URL

    /// The context size.
    public var contextSize: Int

    /// The model slug.
    public var modelSlug: String

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - modelURL: The local `URL` of the model.
    ///   - contextSize: The context size.
    ///   - modelSlug: The model slug.
    public init(modelURL: URL, contextSize: Int = 2048, modelSlug: String? = nil) {
      self.modelURL = modelURL
      self.contextSize = contextSize
      if let modelSlug {
        self.modelSlug = modelSlug
      } else {
        self.modelSlug = modelURL.lastPathComponent
      }
    }
  }
}

// MARK: - Creation Error

extension CactusLanguageModel {
  /// An error thrown when trying to create a model.
  public struct ModelCreationError: Error, Hashable {
    /// The error message.
    public let message: String

    init(configuration: Configuration) {
      if let message = cactus_get_last_error() {
        self.message = String(cString: message)
      } else {
        self.message = "Failed to create model with configuration: \(configuration)"
      }
    }
  }
}

// MARK: - Embeddings

extension CactusLanguageModel {
  /// An error thrown when trying to generate embeddings.
  public enum EmbeddingsError: Error, Hashable {
    /// The buffer size for the generated embeddings was too small.
    case bufferTooSmall

    /// A generation error.
    case generation(message: String?)
  }

  /// Generates embeddings for the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func embeddings(for text: String, maxBufferSize: Int? = nil) throws -> [Float] {
    let maxBufferSize = maxBufferSize ?? self.bufferSize(for: text.utf8.count)
    let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }
    let dimensions = try self.embeddings(for: text, buffer: buffer)
    return (0..<dimensions).map { buffer[$0] }
  }

  #if swift(>=6.2)
    /// Generates embeddings for the specified `text` and stores them in the specified buffer.
    ///
    /// - Parameters:
    ///   - text: The text to generate embeddings for.
    ///   - buffer: A `MutableSpan` buffer.
    /// - Returns: The number of dimensions.
    @discardableResult
    public func embeddings(for text: String, buffer: inout MutableSpan<Float>) throws -> Int {
      try buffer.withUnsafeMutableBufferPointer { try self.embeddings(for: text, buffer: $0) }
    }
  #endif

  /// Generates embeddings for the specified `text` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - text: The text to generate embeddings for.
  ///   - buffer: An `UnsafeMutableBufferPointer` buffer.
  /// - Returns: The number of dimensions.
  public func embeddings(
    for text: String,
    buffer: UnsafeMutableBufferPointer<Float>
  ) throws -> Int {
    let bufferTooSmallEvent = CactusTelemetry.LanguageModelErrorEvent(
      name: "embedding",
      message: "Buffer size too small",
      configuration: self.configuration
    )
    let size = buffer.count
    guard size > 0 else {
      CactusTelemetry.send(bufferTooSmallEvent)
      throw EmbeddingsError.bufferTooSmall
    }
    var dimensions = 0
    let rawBufferSize = size * MemoryLayout<Float>.stride
    switch cactus_embed(self.model, text, buffer.baseAddress, rawBufferSize, &dimensions) {
    case -1:
      let message = cactus_get_last_error().map { String(cString: $0) }
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "embedding",
          message: message ?? "Unknown Error",
          configuration: self.configuration
        )
      )
      throw EmbeddingsError.generation(message: message)
    case -2:
      CactusTelemetry.send(bufferTooSmallEvent)
      throw EmbeddingsError.bufferTooSmall
    default:
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelEmbeddingsEvent(configuration: self.configuration)
      )
      return dimensions
    }
  }
}

// MARK: - Chat Completion

extension CactusLanguageModel {
  /// A chat completion result.
  public struct ChatCompletion: Hashable, Sendable {
    /// The raw response text from the model.
    public let response: String

    /// The tokens per second rate.
    public let tokensPerSecond: Double

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// A list of ``CactusLanguageModel/ToolCall`` instances from the model.
    public let toolCalls: [ToolCall]

    private let timeToFirstTokenMs: Double
    private let totalTimeMs: Double

    /// The amount of time in seconds to generate the first token.
    public var timeIntervalToFirstToken: TimeInterval {
      self.timeToFirstTokenMs / 1000
    }

    /// The total generation time in seconds.
    public var totalTimeInterval: TimeInterval {
      self.totalTimeMs / 1000
    }
  }

  /// An error thrown when trying to generate a ``ChatCompletion``.
  public enum ChatCompletionError: Error, Hashable {
    /// The buffer size for the completion was too small.
    case bufferSizeTooSmall

    /// A generation error.
    case generation(message: String?)
  }

  /// Generates a ``ChatCompletion``.
  ///
  /// - Parameters:
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - options: The ``ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - tools: A list of ``ToolDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``ChatCompletion``.
  public func chatCompletion(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    tools: [ToolDefinition] = [],
    onToken: @escaping (String) -> Void = { _ in }
  ) throws -> ChatCompletion {
    let bufferTooSmallEvent = CactusTelemetry.LanguageModelErrorEvent(
      name: "completion",
      message: "Response buffer too small",
      configuration: self.configuration
    )
    let options = options ?? ChatCompletion.Options(modelType: self.properties.modelType)
    let maxBufferSize = maxBufferSize ?? self.bufferSize(for: options.maxTokens)
    guard maxBufferSize > 0 else {
      CactusTelemetry.send(bufferTooSmallEvent)
      throw ChatCompletionError.bufferSizeTooSmall
    }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let tools = tools.map { _ToolDefinition(function: $0) }
    let toolsJSON =
      tools.isEmpty ? nil : String(decoding: try JSONEncoder().encode(tools), as: UTF8.self)

    let box = Unmanaged.passRetained(TokenCallbackBox(onToken))
    defer { box.release() }
    let result = cactus_complete(
      self.model,
      String(decoding: try JSONEncoder().encode(messages), as: UTF8.self),
      buffer,
      maxBufferSize * MemoryLayout<CChar>.stride,
      String(decoding: try JSONEncoder().encode(options), as: UTF8.self),
      toolsJSON,
      { token, _, ptr in
        guard let ptr, let token else { return }
        let box = Unmanaged<TokenCallbackBox>.fromOpaque(ptr).takeUnretainedValue()
        box.callback(String(cString: token))
      },
      box.toOpaque()
    )

    var responseData = Data()
    for i in 0..<strnlen(buffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: buffer[i]))
    }

    guard result != -1 else {
      let response = try? Self.chatCompletionDecoder.decode(
        CompletionErrorResponse.self,
        from: responseData
      )
      if response?.error == "Response buffer too small" {
        CactusTelemetry.send(bufferTooSmallEvent)
        throw ChatCompletionError.bufferSizeTooSmall
      }
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "completion",
          message: response?.error ?? "Unknown error",
          configuration: self.configuration
        )
      )
      throw ChatCompletionError.generation(message: response?.error)
    }
    let completion = try Self.chatCompletionDecoder.decode(ChatCompletion.self, from: responseData)
    CactusTelemetry.send(
      CactusTelemetry.LanguageModelCompletionEvent(
        chatCompletion: completion,
        options: options,
        configuration: self.configuration
      )
    )
    return completion
  }

  private static let chatCompletionDecoder = {
    let decoder = JSONDecoder()
    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
      decoder.allowsJSON5 = true
    }
    return decoder
  }()

  private struct _ToolDefinition: Codable {
    var function: ToolDefinition
  }

  private final class TokenCallbackBox {
    let callback: (String) -> Void

    init(_ callback: @escaping (String) -> Void) {
      self.callback = callback
    }
  }

  private struct CompletionErrorResponse: Decodable {
    let error: String
  }
}

extension CactusLanguageModel.ChatCompletion {
  /// Options for generating a ``CactusLanguageModel/ChatCompletion``
  public struct Options: Hashable, Sendable, Codable {
    /// The maximum number of tokens for the completion.
    public var maxTokens: Int

    /// The temperature.
    public var temperature: Float

    /// The nucleus sampling.
    public var topP: Float

    /// The k most probable options to limit the next word to.
    public var topK: Int

    /// An array of stop sequence phrases.
    public var stopSequences: [String]

    /// Creates options for generating a ``CactusLanguageModel/ChatCompletion``.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: The temperature.
    ///   - topP: The nucleus sampling.
    ///   - topK: The k most probable options to limit the next word to.
    ///   - stopSequences: An array of stop sequence phrases.
    public init(
      maxTokens: Int = 200,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = ["<|im_end|>", "<end_of_turn>"]
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.stopSequences = stopSequences
    }

    /// Creates options for generating a ``CactusLanguageModel/ChatCompletion``.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - modelType: The model type.
    ///   - stopSequences: An array of stop sequence phrases.
    public init(
      maxTokens: Int = 200,
      modelType: CactusLanguageModel.ModelType,
      stopSequences: [String] = ["<|im_end|>", "<end_of_turn>"]
    ) {
      self.maxTokens = maxTokens
      self.temperature = modelType.defaultTemperature
      self.topP = modelType.defaultTopP
      self.topK = modelType.defaultTopK
      self.stopSequences = stopSequences
    }

    private enum CodingKeys: String, CodingKey {
      case maxTokens = "max_tokens"
      case temperature
      case topP = "top_p"
      case topK = "top_k"
      case stopSequences = "stop_sequences"
    }
  }
}

extension CactusLanguageModel.ChatCompletion: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.response = try container.decode(String.self, forKey: .response)
    self.tokensPerSecond = try container.decode(Double.self, forKey: .tokensPerSecond)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.toolCalls =
      try container.decodeIfPresent([CactusLanguageModel.ToolCall].self, forKey: .toolCalls) ?? []
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusLanguageModel.ChatCompletion: Encodable {
  private enum CodingKeys: String, CodingKey {
    case response
    case tokensPerSecond = "tokens_per_second"
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case toolCalls = "function_calls"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - Stop

extension CactusLanguageModel {
  /// Stops generation of an active chat completion.
  ///
  /// This method is safe to call from other threads.
  public func stop() {
    cactus_stop(self.model)
  }
}

// MARK: - Reset

extension CactusLanguageModel {
  /// Resets the context state of the model.
  public func reset() {
    cactus_reset(self.model)
  }
}

// MARK: - Helpers

extension CactusLanguageModel {
  private func bufferSize(for contentLength: Int) -> Int {
    max(contentLength * self.properties.precision.bits, 1024)
  }
}
