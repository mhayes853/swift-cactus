import CXXCactusShims
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
  @available(*, deprecated, message: "Use `configurationFile` instead.")
  public var properties: Properties {
    Properties(file: self.configurationFile)
  }

  /// The ``ConfigurationFile`` for this model.
  public let configurationFile: ConfigurationFile

  /// The underlying model pointer.
  public let model: cactus_model_t

  private let isModelPointerManaged: Bool

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - contextSize: The context size.
  ///   - modelSlug: The model slug.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  public convenience init(
    from url: URL,
    contextSize: Int = 2048,
    modelSlug: String? = nil,
    corpusDirectoryURL: URL? = nil
  ) throws {
    let configuration = Configuration(
      modelURL: url,
      contextSize: contextSize,
      modelSlug: modelSlug,
      corpusDirectoryURL: corpusDirectoryURL
    )
    try self.init(configuration: configuration)
  }

  /// Loads a model from the specified ``Configuration``.
  ///
  /// - Parameter configuration: The ``Configuration``.
  public init(configuration: Configuration) throws {
    do {
      self.configuration = configuration
      let model = cactus_init(
        configuration.modelURL.nativePath,
        configuration.contextSize,
        configuration.corpusDirectoryURL?.nativePath
      )
      guard let model else { throw ModelCreationError(configuration: configuration) }
      self.model = model
      let configFile = try ConfigurationFile(
        contentsOf: configuration.modelURL.appendingPathComponent("config.txt")
      )
      self.configurationFile = configFile
      self.isModelPointerManaged = true
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

  /// Creates a language model from the specified model pointer and configuration.
  ///
  /// The configuration must accurately represent the underlying properties of the model pointer.
  ///
  /// - Parameters:
  ///   - model: The model pointer.
  ///   - configuration: A ``Configuration`` that must accurately represent the model.
  ///   - isModelPointerManaged: Whether or not the model pointer is destroyed when the language
  ///     model is deinitialized.
  public init(
    model: cactus_model_t,
    configuration: Configuration,
    isModelPointerManaged: Bool = false
  ) throws {
    self.configuration = configuration
    self.configurationFile = try ConfigurationFile(
      contentsOf: configuration.modelURL.appendingPathComponent("config.txt")
    )
    self.model = model
    self.isModelPointerManaged = isModelPointerManaged
    CactusTelemetry.send(CactusTelemetry.LanguageModelInitEvent(configuration: configuration))
  }

  deinit {
    if self.isModelPointerManaged {
      cactus_destroy(self.model)
    }
  }
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

    /// A `URL` to a corpus directory of documents for RAG models.
    public var corpusDirectoryURL: URL?

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - modelURL: The local `URL` of the model.
    ///   - contextSize: The context size.
    ///   - modelSlug: The model slug.
    ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
    public init(
      modelURL: URL,
      contextSize: Int = 2048,
      modelSlug: String? = nil,
      corpusDirectoryURL: URL? = nil
    ) {
      self.modelURL = modelURL
      self.contextSize = contextSize
      if let modelSlug {
        self.modelSlug = modelSlug
      } else {
        self.modelSlug = modelURL.lastPathComponent
      }
      self.corpusDirectoryURL = corpusDirectoryURL
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

// MARK: - Tokenize

extension CactusLanguageModel {
  /// An error thrown when trying to tokenize text.
  public enum TokenizeError: Error, Hashable {
    /// The buffer size for the tokenized output was too small.
    case bufferTooSmall

    /// An error occurred during tokenization.
    case invalidTokenization
  }

  public func tokenize(text: String, maxBufferSize: Int = 1024) throws -> [UInt32] {
    let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }
    let count = try self.tokenize(text: text, buffer: buffer)
    return Array(buffer.prefix(count))
  }

  @discardableResult
  public func tokenize(text: String, buffer: inout MutableSpan<UInt32>) throws -> Int {
    try buffer.withUnsafeMutableBufferPointer { try self.tokenize(text: text, buffer: $0) }
  }

  @discardableResult
  public func tokenize(text: String, buffer: UnsafeMutableBufferPointer<UInt32>) throws -> Int {
    var tokenLength = 0
    let resultCode = cactus_tokenize(
      self.model,
      text,
      buffer.baseAddress,
      buffer.count,
      &tokenLength
    )
    switch resultCode {
    case -1:
      throw TokenizeError.invalidTokenization
    case -2:
      throw TokenizeError.bufferTooSmall
    default:
      return tokenLength
    }
  }
}

// MARK: - Embeddings

extension CactusLanguageModel {
  /// An error thrown when trying to generate embeddings.
  public enum EmbeddingsError: Error, Hashable {
    /// The buffer size for the generated embeddings was too small.
    case bufferTooSmall

    /// The model doesn't support image embeddings.
    case imageNotSupported

    /// The model doesn't support audio embeddings.
    case audioNotSupported

    /// A generation error.
    case generation(message: String?)
  }

  /// Generates embeddings for the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  ///   - normalize: Whether to normalize the embeddings.
  /// - Returns: An array of float values.
  public func embeddings(
    for text: String,
    maxBufferSize: Int? = nil,
    normalize: Bool = false
  ) throws -> [Float] {
    try self.embeddings(for: .text(text, normalize: normalize), maxBufferSize: maxBufferSize)
  }

  /// Generates embeddings for the specified `text` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - text: The text to generate embeddings for.
  ///   - buffer: A `MutableSpan` buffer.
  ///   - normalize: Whether to normalize the embeddings.
  /// - Returns: The number of dimensions.
  @discardableResult
  public func embeddings(
    for text: String,
    buffer: inout MutableSpan<Float>,
    normalize: Bool = false
  ) throws -> Int {
    try self.embeddings(for: .text(text, normalize: normalize), buffer: &buffer)
  }

  /// Generates embeddings for the specified `text` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - text: The text to generate embeddings for.
  ///   - buffer: An `UnsafeMutableBufferPointer` buffer.
  ///   - normalize: Whether to normalize the embeddings.
  /// - Returns: The number of dimensions.
  public func embeddings(
    for text: String,
    buffer: UnsafeMutableBufferPointer<Float>,
    normalize: Bool = false
  ) throws -> Int {
    try self.embeddings(for: .text(text, normalize: normalize), buffer: buffer)
  }

  /// Generates embeddings for the specified `image`.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func imageEmbeddings(for image: URL, maxBufferSize: Int? = nil) throws -> [Float] {
    try self.embeddings(for: .image(image), maxBufferSize: maxBufferSize)
  }

  /// Generates embeddings for the specified `image` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - buffer: A `MutableSpan` buffer.
  /// - Returns: The number of dimensions.
  @discardableResult
  public func imageEmbeddings(for image: URL, buffer: inout MutableSpan<Float>) throws -> Int {
    try self.embeddings(for: .image(image), buffer: &buffer)
  }

  /// Generates embeddings for the specified `image` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - buffer: An `UnsafeMutableBufferPointer` buffer.
  /// - Returns: The number of dimensions.
  public func imageEmbeddings(
    for image: URL,
    buffer: UnsafeMutableBufferPointer<Float>
  ) throws -> Int {
    try self.embeddings(for: .image(image), buffer: buffer)
  }

  /// Generates embeddings for the specified `audio`.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func audioEmbeddings(for audio: URL, maxBufferSize: Int? = nil) throws -> [Float] {
    try self.embeddings(for: .audio(audio), maxBufferSize: maxBufferSize)
  }

  /// Generates embeddings for the specified `audio` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - buffer: A `MutableSpan` buffer.
  /// - Returns: The number of dimensions.
  @discardableResult
  public func audioEmbeddings(for audio: URL, buffer: inout MutableSpan<Float>) throws -> Int {
    try self.embeddings(for: .audio(audio), buffer: &buffer)
  }

  /// Generates embeddings for the specified `audio` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - buffer: An `UnsafeMutableBufferPointer` buffer.
  /// - Returns: The number of dimensions.
  public func audioEmbeddings(
    for audio: URL,
    buffer: UnsafeMutableBufferPointer<Float>
  ) throws -> Int {
    try self.embeddings(for: .audio(audio), buffer: buffer)
  }

  private func embeddings(
    for request: EmbeddingsRequest,
    maxBufferSize: Int?
  ) throws -> [Float] {
    let maxBufferSize = maxBufferSize ?? self.defaultEmbeddingsBufferSize
    let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }
    let dimensions = try self.embeddings(for: request, buffer: buffer)
    return (0..<dimensions).map { buffer[$0] }
  }

  @discardableResult
  private func embeddings(
    for request: EmbeddingsRequest,
    buffer: inout MutableSpan<Float>
  ) throws -> Int {
    try buffer.withUnsafeMutableBufferPointer { try self.embeddings(for: request, buffer: $0) }
  }

  private func embeddings(
    for request: EmbeddingsRequest,
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

    let resultCode =
      switch request {
      case .text(let text, let normalize):
        cactus_embed(self.model, text, buffer.baseAddress, rawBufferSize, &dimensions, normalize)
      case .image(let image):
        cactus_image_embed(
          self.model,
          image.nativePath,
          buffer.baseAddress,
          rawBufferSize,
          &dimensions
        )
      case .audio(let audio):
        cactus_audio_embed(
          self.model,
          audio.nativePath,
          buffer.baseAddress,
          rawBufferSize,
          &dimensions
        )
      }

    switch resultCode {
    case -1:
      let message = cactus_get_last_error().map { String(cString: $0) }
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "embedding",
          message: message ?? "Unknown Error",
          configuration: self.configuration
        )
      )

      if message?.contains("Image embeddings") == true {
        throw EmbeddingsError.imageNotSupported
      } else if message?.contains("Audio embeddings") == true {
        throw EmbeddingsError.audioNotSupported
      } else {
        throw EmbeddingsError.generation(message: message)
      }
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

  private enum EmbeddingsRequest {
    case text(String, normalize: Bool)
    case image(URL)
    case audio(URL)
  }

  private var defaultEmbeddingsBufferSize: Int {
    self.configurationFile.hiddenDimensions ?? 1024
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

    /// A list of ``CactusLanguageModel/FunctionCall`` instances from the model.
    public let functionCalls: [FunctionCall]

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
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``ChatCompletion``.
  public func chatCompletion(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> ChatCompletion {
    let bufferTooSmallEvent = CactusTelemetry.LanguageModelErrorEvent
      .responseBufferTooSmall(name: "completion", configuration: self.configuration)
    let options =
      options ?? ChatCompletion.Options(modelType: self.configurationFile.modelType ?? .qwen)
    let maxBufferSize = maxBufferSize ?? self.bufferSize(for: options.maxTokens)
    guard maxBufferSize > 0 else {
      CactusTelemetry.send(bufferTooSmallEvent)
      throw ChatCompletionError.bufferSizeTooSmall
    }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let functions = functions.map { FFIFunctionDefinition(function: $0) }
    let functionsJSON =
      functions.isEmpty
      ? nil
      : String(decoding: try Self.inferenceEncoder.encode(functions), as: UTF8.self)

    let messages = messages.map { FFIMessage(message: $0) }

    let result = try withTokenCallback(onToken) { userData, onToken in
      cactus_complete(
        self.model,
        String(decoding: try Self.inferenceEncoder.encode(messages), as: UTF8.self),
        buffer,
        maxBufferSize * MemoryLayout<CChar>.stride,
        String(decoding: try Self.inferenceEncoder.encode(options), as: UTF8.self),
        functionsJSON,
        onToken,
        userData
      )
    }

    var responseData = Data()
    for i in 0..<strnlen(buffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: buffer[i]))
    }

    guard result != -1 else {
      let response = try? Self.inferenceDecoder.decode(
        InferenceErrorResponse.self,
        from: responseData
      )
      if response?.error.contains(bufferTooSmallEvent.message) == true {
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
    let completion = try Self.inferenceDecoder.decode(ChatCompletion.self, from: responseData)
    CactusTelemetry.send(
      CactusTelemetry.LanguageModelCompletionEvent(
        chatCompletion: completion,
        options: options,
        configuration: self.configuration
      )
    )
    return completion
  }

  private struct FFIFunctionDefinition: Codable {
    var function: FunctionDefinition
  }

  private struct FFIMessage: Codable {
    let role: MessageRole
    let content: String
    let images: [String]?

    init(message: ChatMessage) {
      self.role = message.role
      self.content = message.content
      self.images = message.images?.map(\.nativePath)
    }
  }
}

extension CactusLanguageModel.ChatCompletion {
  /// Options for generating a ``CactusLanguageModel/ChatCompletion``.
  public typealias Options = CactusLanguageModel.InferenceOptions
}

extension CactusLanguageModel.ChatCompletion: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.response = try container.decode(String.self, forKey: .response)
    self.tokensPerSecond = try container.decode(Double.self, forKey: .tokensPerSecond)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.functionCalls =
      try container.decodeIfPresent([CactusLanguageModel.FunctionCall].self, forKey: .functionCalls)
      ?? []
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
    case functionCalls = "function_calls"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - Transcribe

extension CactusLanguageModel {
  /// An error thrown when trying to generate a ``Transcription``.
  public enum TranscriptionError: Error, Hashable {
    /// The buffer size for the completion was too small.
    case bufferSizeTooSmall

    /// The model does not support transcription.
    case notSupported

    /// A generation error.
    case generation(message: String?)
  }

  /// A transcription result.
  public struct Transcription: Hashable, Sendable {
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

  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: Transcription.Options? = nil,
    transcriptionMaxBufferSize: Int? = nil,
    onToken: (String) -> Void = { _ in }
  ) throws -> Transcription {
    try self.transcribe(
      for: .buffer(buffer),
      prompt: prompt,
      options: options,
      maxBufferSize: transcriptionMaxBufferSize,
      onToken: onToken
    )
  }

  /// Transcribes the specified `audio` file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``Transcription/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``Transcription``.
  public func transcribe(
    audio: URL,
    prompt: String,
    options: Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: (String) -> Void = { _ in }
  ) throws -> Transcription {
    try self.transcribe(
      for: .audio(audio),
      prompt: prompt,
      options: options,
      maxBufferSize: maxBufferSize,
      onToken: onToken
    )
  }
}

extension CactusLanguageModel {
  private enum TranscriptionRequest {
    case audio(URL)
    case buffer([UInt8])
  }

  private func transcribe(
    for request: TranscriptionRequest,
    prompt: String,
    options: Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: (String) -> Void = { _ in }
  ) throws -> Transcription {
    guard self.configurationFile.modelType == .whisper else {
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "transcription",
          message: "Transcription not supported",
          configuration: self.configuration
        )
      )
      throw TranscriptionError.notSupported
    }

    let bufferTooSmallEvent = CactusTelemetry.LanguageModelErrorEvent
      .responseBufferTooSmall(name: "transcription", configuration: self.configuration)
    let options = options ?? Transcription.Options(modelType: .whisper)
    let maxBufferSize = maxBufferSize ?? self.bufferSize(for: options.maxTokens)
    guard maxBufferSize > 0 else {
      CactusTelemetry.send(bufferTooSmallEvent)
      throw TranscriptionError.bufferSizeTooSmall
    }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let result = try withTokenCallback(onToken) { userData, onToken in
      switch request {
      case .audio(let audio):
        return cactus_transcribe(
          self.model,
          audio.nativePath,
          prompt,
          buffer,
          maxBufferSize * MemoryLayout<CChar>.stride,
          String(decoding: try Self.inferenceEncoder.encode(options), as: UTF8.self),
          onToken,
          userData,
          nil,
          0
        )
      case .buffer(let pcmBuffer):
        return try pcmBuffer.withUnsafeBufferPointer { rawBuffer in
          cactus_transcribe(
            self.model,
            nil,
            prompt,
            buffer,
            maxBufferSize * MemoryLayout<CChar>.stride,
            String(decoding: try Self.inferenceEncoder.encode(options), as: UTF8.self),
            onToken,
            userData,
            rawBuffer.baseAddress,
            rawBuffer.count
          )
        }
      }
    }

    var responseData = Data()
    for i in 0..<strnlen(buffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: buffer[i]))
    }

    guard result != -1 else {
      let response = try? Self.inferenceDecoder.decode(
        InferenceErrorResponse.self,
        from: responseData
      )
      if response?.error.contains(bufferTooSmallEvent.message) == true {
        CactusTelemetry.send(bufferTooSmallEvent)
        throw TranscriptionError.bufferSizeTooSmall
      }
      CactusTelemetry.send(
        CactusTelemetry.LanguageModelErrorEvent(
          name: "transcription",
          message: response?.error ?? "Unknown error",
          configuration: self.configuration
        )
      )
      throw TranscriptionError.generation(message: response?.error)
    }
    let transcription = try Self.inferenceDecoder.decode(Transcription.self, from: responseData)
    CactusTelemetry.send(
      CactusTelemetry.LanguageModelTranscriptionEvent(
        transcription: transcription,
        options: options,
        configuration: self.configuration
      )
    )
    return transcription
  }
}

extension CactusLanguageModel.Transcription {
  /// Options for generating a ``CactusLanguageModel/Transcription``.
  public typealias Options = CactusLanguageModel.InferenceOptions
}

extension CactusLanguageModel.Transcription: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.response = try container.decode(String.self, forKey: .response)
    self.tokensPerSecond = try container.decode(Double.self, forKey: .tokensPerSecond)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusLanguageModel.Transcription: Encodable {
  private enum CodingKeys: String, CodingKey {
    case response
    case tokensPerSecond = "tokens_per_second"
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - InferenceOptions

extension CactusLanguageModel {
  /// Options for generating inferences.
  public struct InferenceOptions: Hashable, Sendable, Codable {
    /// A default array of common stop sequences.
    public static let defaultStopSequences = ["<|im_end|>", "<end_of_turn>"]

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

    /// Whether to force functions to be used by the model.
    public var forceFunctions: Bool

    /// Creates options for generating inferences.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: The temperature.
    ///   - topP: The nucleus sampling.
    ///   - topK: The k most probable options to limit the next word to.
    ///   - stopSequences: An array of stop sequence phrases.
    ///   - forceFunctions: Whether to force functions to be used by the model.
    public init(
      maxTokens: Int = 200,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = Self.defaultStopSequences,
      forceFunctions: Bool = false
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.stopSequences = stopSequences
      self.forceFunctions = forceFunctions
    }

    /// Creates options for generating inferences.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - modelType: The model type.
    ///   - stopSequences: An array of stop sequence phrases.
    ///   - forceFunctions: Whether to force functions to be used by the model.
    public init(
      maxTokens: Int = 200,
      modelType: CactusLanguageModel.ModelType,
      stopSequences: [String] = Self.defaultStopSequences,
      forceFunctions: Bool = false
    ) {
      self.maxTokens = maxTokens
      self.temperature = modelType.defaultTemperature
      self.topP = modelType.defaultTopP
      self.topK = modelType.defaultTopK
      self.stopSequences = stopSequences
      self.forceFunctions = forceFunctions
    }

    private enum CodingKeys: String, CodingKey {
      case maxTokens = "max_tokens"
      case temperature
      case topP = "top_p"
      case topK = "top_k"
      case stopSequences = "stop_sequences"
      case forceFunctions = "force_tools"
    }
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
    max(
      contentLength * (self.configurationFile.precision?.bits ?? 32),
      self.configurationFile.hiddenDimensions ?? 1024
    )
  }
}

extension CactusLanguageModel {
  private struct InferenceErrorResponse: Decodable {
    let error: String
  }

  private static let inferenceDecoder = {
    let decoder = JSONDecoder()
    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
      decoder.allowsJSON5 = true
    }
    return decoder
  }()

  private static let inferenceEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
  }()
}

// MARK: - Token Callback

private func withTokenCallback<T>(
  _ callback: (String) -> Void,
  perform operation: (UnsafeMutableRawPointer, cactus_token_callback) throws -> T
) rethrows -> T {
  try withoutActuallyEscaping(callback) { onToken in
    let box = Unmanaged.passRetained(TokenCallbackBox(onToken))
    defer { box.release() }
    return try operation(box.toOpaque()) { token, _, ptr in
      guard let ptr, let token else { return }
      let box = Unmanaged<TokenCallbackBox>.fromOpaque(ptr).takeUnretainedValue()
      box.callback(String(cString: token))
    }
  }
}

private final class TokenCallbackBox {
  let callback: (String) -> Void

  init(_ callback: @escaping (String) -> Void) {
    self.callback = callback
  }
}
