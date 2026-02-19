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

  /// The ``ConfigurationFile`` for this model.
  public let configurationFile: ConfigurationFile

  /// The underlying model pointer.
  public let model: cactus_model_t

  private let isModelPointerManaged: Bool

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - modelSlug: The model slug.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  public convenience init(
    from url: URL,
    modelSlug: String? = nil,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false
  ) throws {
    let configuration = Configuration(
      modelURL: url,
      modelSlug: modelSlug,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    try self.init(configuration: configuration)
  }

  /// Loads a model from the specified ``Configuration``.
  ///
  /// - Parameter configuration: The ``Configuration``.
  public init(configuration: Configuration) throws {
    self.configuration = configuration
    let model = cactus_init(
      configuration.modelURL.nativePath,
      configuration.corpusDirectoryURL?.nativePath,
      configuration.cacheIndex
    )
    guard let model else { throw ModelCreationError(configuration: configuration) }
    self.model = model
    let configFile = try ConfigurationFile(
      contentsOf: configuration.modelURL.appendingPathComponent("config.txt")
    )
    self.configurationFile = configFile
    self.isModelPointerManaged = true
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

    /// The model slug.
    public var modelSlug: String

    /// A `URL` to a corpus directory of documents for RAG models.
    public var corpusDirectoryURL: URL?

    /// Whether to load a cached RAG index if available.
    public var cacheIndex: Bool

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - modelURL: The local `URL` of the model.
    ///   - modelSlug: The model slug.
    ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
    ///   - cacheIndex: Whether to load a cached RAG index if available.
    public init(
      modelURL: URL,
      modelSlug: String? = nil,
      corpusDirectoryURL: URL? = nil,
      cacheIndex: Bool = false
    ) {
      self.modelURL = modelURL
      if let modelSlug {
        self.modelSlug = modelSlug
      } else {
        let splits = modelURL.lastPathComponent.components(separatedBy: "--")
        self.modelSlug = splits.isEmpty ? modelURL.lastPathComponent : splits[0]
      }
      self.corpusDirectoryURL = corpusDirectoryURL
      self.cacheIndex = cacheIndex
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

  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - maxBufferSize: The maximum buffer size for the tokenized output.
  /// - Returns: An array of raw tokens.
  public func tokenize(text: String, maxBufferSize: Int = 8192) throws -> [UInt32] {
    let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }
    let count = try self.tokenize(text: text, buffer: buffer)
    return Array(buffer.prefix(count))
  }

  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - buffer: The buffer to store the tokenized output.
  /// - Returns: The total number of tokens.
  @discardableResult
  public func tokenize(text: String, buffer: inout MutableSpan<UInt32>) throws -> Int {
    try buffer.withUnsafeMutableBufferPointer { try self.tokenize(text: text, buffer: $0) }
  }

  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - buffer: The buffer to store the tokenized output.
  /// - Returns: The total number of tokens.
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

// MARK: - Score Window

extension CactusLanguageModel {
  /// An error thrown when trying to score a token window.
  public struct ScoreTokenWindowError: Error, Hashable {
    public let message: String
  }

  /// Log probability score of a token window.
  public struct TokenWindowScore: Hashable, Codable, Sendable {
    /// The log probability.
    public let logProbability: Double

    /// The number of tokens scored.
    public let tokensScored: Int

    private enum CodingKeys: String, CodingKey {
      case logProbability = "logprob"
      case tokensScored = "tokens"
    }
  }

  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: [UInt32],
    range: Range<Int>? = nil,
    context: Int
  ) throws -> TokenWindowScore {
    try tokens.withUnsafeBufferPointer { buffer in
      try self.scoreTokenWindow(tokens: buffer, range: range, context: context)
    }
  }

  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: Span<UInt32>,
    range: Range<Int>? = nil,
    context: Int
  ) throws -> TokenWindowScore {
    try tokens.withUnsafeBufferPointer { buffer in
      try self.scoreTokenWindow(tokens: buffer, range: range, context: context)
    }
  }

  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: UnsafeBufferPointer<UInt32>,
    range: Range<Int>? = nil,
    context: Int
  ) throws -> TokenWindowScore {
    let start = range?.lowerBound ?? 0
    let end = range?.upperBound ?? tokens.count
    let responseBufferSize = 256
    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: responseBufferSize)
    defer { responseBuffer.deallocate() }

    let result = cactus_score_window(
      self.model,
      tokens.baseAddress,
      tokens.count,
      start,
      end,
      context,
      responseBuffer,
      responseBufferSize * MemoryLayout<CChar>.stride
    )

    var responseData = Data()
    for i in 0..<strnlen(responseBuffer, responseBufferSize) {
      responseData.append(UInt8(bitPattern: responseBuffer[i]))
    }

    guard result != -1 else {
      let errorResponse = try ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )
      throw ScoreTokenWindowError(message: errorResponse.error)
    }
    return try ffiDecoder.decode(TokenWindowScore.self, from: responseData)
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
    let size = buffer.count
    guard size > 0 else {
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

      if message?.contains("Image embeddings") == true {
        throw EmbeddingsError.imageNotSupported
      } else if message?.contains("Audio embeddings") == true {
        throw EmbeddingsError.audioNotSupported
      } else {
        throw EmbeddingsError.generation(message: message)
      }
    case -2:
      throw EmbeddingsError.bufferTooSmall
    default:
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

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// A list of ``CactusLanguageModel/FunctionCall`` instances from the model.
    public let functionCalls: [FunctionCall]

    /// The model's confidence in its response.
    public let confidence: Double

    /// The prefill tokens per second.
    public let prefillTps: Double

    /// The decode tokens per second.
    public let decodeTps: Double

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

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

  /// A completed chat turn with canonical continuation messages.
  public struct CompletedChatTurn: Hashable, Sendable {
    /// The raw completion returned by the model.
    public let completion: ChatCompletion

    /// Canonical conversation messages that include the generated assistant turn.
    public let messages: [ChatMessage]
  }

  /// An error thrown when trying to generate a ``ChatCompletion``.
  public enum ChatCompletionError: Error, Hashable {
    /// The buffer size for the completion was too small.
    case bufferSizeTooSmall

    /// A generation error.
    case generation(message: String?)
  }

  /// Generates a completed chat turn with reusable continuation messages.
  ///
  /// This API returns both the completion payload and a canonical `messages` array that includes
  /// the generated assistant response, making it suitable for direct reuse in subsequent calls.
  ///
  /// ```swift
  /// let first = try model.complete(
  ///   messages: [
  ///     .system("You are a concise assistant."),
  ///     .user("Summarize Swift actors in one sentence.")
  ///   ]
  /// )
  ///
  /// let second = try model.complete(
  ///   messages: first.messages + [.user("Now make it even shorter.")]
  /// )
  /// print(second.completion.response)
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - options: The ``ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CompletedChatTurn``.
  public func complete(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> CompletedChatTurn {
    try self.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _ in
      onToken(token)
    }
  }

  /// Generates a completed chat turn with reusable continuation messages.
  ///
  /// ```swift
  /// let turn = try model.complete(
  ///   messages: [
  ///     .system("You are a concise assistant."),
  ///     .user("List three Swift concurrency features.")
  ///   ]
  /// ) { token, tokenID in
  ///   print(tokenID, token)
  /// }
  /// print(turn.messages.last?.content ?? "")
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - options: The ``ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CompletedChatTurn``.
  public func complete(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> CompletedChatTurn {
    let options =
      options ?? ChatCompletion.Options(modelType: self.configurationFile.modelType ?? .qwen)
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else {
      throw ChatCompletionError.bufferSizeTooSmall
    }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let functions = functions.map { FFIFunctionDefinition(function: $0) }
    let functionsJSON =
      functions.isEmpty
      ? nil
      : String(decoding: try ffiEncoder.encode(functions), as: UTF8.self)

    let ffiMessages = messages.map { FFIMessage(message: $0) }
    var streamedResponse = ""

    let result = try withTokenCallback { token, tokenID in
      streamedResponse += token
      onToken(token, tokenID)
    } perform: { userData, onToken in
      cactus_complete(
        self.model,
        String(decoding: try ffiEncoder.encode(ffiMessages), as: UTF8.self),
        buffer,
        maxBufferSize * MemoryLayout<CChar>.stride,
        String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
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
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )
      if response?.error.contains("Buffer not big enough") == true {
        throw ChatCompletionError.bufferSizeTooSmall
      }
      throw ChatCompletionError.generation(message: response?.error)
    }
    let completion = try ffiDecoder.decode(ChatCompletion.self, from: responseData)
    var completedMessages = messages
    completedMessages.append(
      .assistant(
        completion.response.count > streamedResponse.count ? completion.response : streamedResponse
      )
    )
    return CompletedChatTurn(completion: completion, messages: completedMessages)
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
  @available(
    *,
    deprecated,
    message:
      "Prefer complete(...) to receive canonical continuation messages for better cache reuse."
  )
  public func chatCompletion(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> ChatCompletion {
    try self.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
    .completion
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
  @available(
    *,
    deprecated,
    message:
      "Prefer complete(...) to receive canonical continuation messages for better cache reuse."
  )
  public func chatCompletion(
    messages: [ChatMessage],
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> ChatCompletion {
    try self.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
    .completion
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
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.functionCalls =
      try container.decodeIfPresent([CactusLanguageModel.FunctionCall].self, forKey: .functionCalls)
      ?? []
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.prefillTps = try container.decode(Double.self, forKey: .prefillTps)
    self.decodeTps = try container.decode(Double.self, forKey: .decodeTps)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusLanguageModel.ChatCompletion: Encodable {
  private enum CodingKeys: String, CodingKey {
    case response
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case functionCalls = "function_calls"
    case confidence
    case prefillTps = "prefill_tps"
    case decodeTps = "decode_tps"
    case ramUsageMb = "ram_usage_mb"
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

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// The model's confidence in its response.
    public let confidence: Double

    /// The prefill tokens per second.
    public let prefillTps: Double

    /// The decode tokens per second.
    public let decodeTps: Double

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

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
      buffer: buffer,
      prompt: prompt,
      options: options,
      transcriptionMaxBufferSize: transcriptionMaxBufferSize
    ) { token, _ in
      onToken(token)
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
    onToken: (String, UInt32) -> Void
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
      audio: audio,
      prompt: prompt,
      options: options,
      maxBufferSize: maxBufferSize
    ) { token, _ in
      onToken(token)
    }
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
    onToken: (String, UInt32) -> Void
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
    onToken: (String, UInt32) -> Void
  ) throws -> Transcription {
    guard self.configurationFile.modelType == .whisper else {
      throw TranscriptionError.notSupported
    }

    let options = options ?? Transcription.Options(modelType: .whisper)
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else {
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
          String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
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
            String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
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
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )
      if response?.error.contains("Buffer not big enough") == true {
        throw TranscriptionError.bufferSizeTooSmall
      }
      throw TranscriptionError.generation(message: response?.error)
    }
    let transcription = try ffiDecoder.decode(Transcription.self, from: responseData)
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
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.prefillTps = try container.decode(Double.self, forKey: .prefillTps)
    self.decodeTps = try container.decode(Double.self, forKey: .decodeTps)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusLanguageModel.Transcription: Encodable {
  private enum CodingKeys: String, CodingKey {
    case response
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case confidence
    case prefillTps = "prefill_tps"
    case decodeTps = "decode_tps"
    case ramUsageMb = "ram_usage_mb"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - VAD

extension CactusLanguageModel {
  /// An error thrown when trying to run voice activity detection.
  public enum VADError: Error, Hashable {
    /// The buffer size for the response was too small.
    case bufferSizeTooSmall

    /// The model does not support voice activity detection.
    case notSupported

    /// A generation error.
    case generation(message: String?)
  }

  /// A detected speech segment.
  public struct VADSegment: Hashable, Sendable, Codable {
    /// Segment start frame.
    public let startFrame: Int

    /// Segment end frame.
    public let endFrame: Int

    private enum CodingKeys: String, CodingKey {
      case startFrame = "start"
      case endFrame = "end"
    }
  }

  /// A voice activity detection result.
  public struct VADResult: Hashable, Sendable {
    /// The detected speech segments.
    public let segments: [VADSegment]

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

    private let totalTimeMs: Double

    /// The total processing time in seconds.
    public var totalTime: TimeInterval {
      self.totalTimeMs / 1000
    }
  }

  /// Options for voice activity detection.
  public struct VADOptions: Hashable, Sendable {
    /// Detection threshold.
    public var threshold: Float?

    /// Negative threshold.
    public var negThreshold: Float?

    /// The minimum speech duration in seconds.
    public var minSpeechDuration: TimeInterval?

    /// The maximum speech duration in seconds.
    public var maxSpeechDuration: TimeInterval?

    /// The minimum silence duration in seconds.
    public var minSilenceDuration: TimeInterval?

    /// The amount of padding in milliseconds to add around speech segments.
    public var speechPadMs: Int?

    /// The VAD window size in samples.
    public var windowSizeSamples: Int?

    /// Minimum silence at max speech in milliseconds.
    public var minSilenceAtMaxSpeech: Int?

    /// Whether to use max possible silence at max speech.
    public var useMaxPossSilAtMaxSpeech: Bool?

    /// Sampling rate in Hz.
    public var samplingRate: Int?

    /// Creates options for voice activity detection.
    public init(
      threshold: Float? = nil,
      negThreshold: Float? = nil,
      minSpeechDuration: TimeInterval? = nil,
      maxSpeechDuration: TimeInterval? = nil,
      minSilenceDuration: TimeInterval? = nil,
      speechPadMs: Int? = nil,
      windowSizeSamples: Int? = nil,
      minSilenceAtMaxSpeech: Int? = nil,
      useMaxPossSilAtMaxSpeech: Bool? = nil,
      samplingRate: Int? = nil
    ) {
      self.threshold = threshold
      self.negThreshold = negThreshold
      self.minSpeechDuration = minSpeechDuration
      self.maxSpeechDuration = maxSpeechDuration
      self.minSilenceDuration = minSilenceDuration
      self.speechPadMs = speechPadMs
      self.windowSizeSamples = windowSizeSamples
      self.minSilenceAtMaxSpeech = minSilenceAtMaxSpeech
      self.useMaxPossSilAtMaxSpeech = useMaxPossSilAtMaxSpeech
      self.samplingRate = samplingRate
    }

    private enum CodingKeys: String, CodingKey {
      case threshold
      case negThreshold = "neg_threshold"
      case minSpeechDuration = "min_speech_duration_ms"
      case maxSpeechDuration = "max_speech_duration_s"
      case minSilenceDuration = "min_silence_duration_ms"
      case speechPadMs = "speech_pad_ms"
      case windowSizeSamples = "window_size_samples"
      case minSilenceAtMaxSpeech = "min_silence_at_max_speech"
      case useMaxPossSilAtMaxSpeech = "use_max_poss_sil_at_max_speech"
      case samplingRate = "sampling_rate"
    }
  }

  private enum VADRequest {
    case audio(URL)
    case buffer([UInt8])
  }

  /// Runs voice activity detection on an audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``VADResult``.
  public func vad(
    audio: URL,
    options: VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) throws -> VADResult {
    try self.vad(for: .audio(audio), options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``VADResult``.
  public func vad(
    pcmBuffer: [UInt8],
    options: VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) throws -> VADResult {
    try self.vad(for: .buffer(pcmBuffer), options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``VADResult``.
  public func vad(
    pcmBuffer: UnsafeBufferPointer<UInt8>,
    options: VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) throws -> VADResult {
    try self.vad(for: .buffer(Array(pcmBuffer)), options: options, maxBufferSize: maxBufferSize)
  }

  private func vad(
    for request: VADRequest,
    options: VADOptions?,
    maxBufferSize: Int?
  ) throws -> VADResult {
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else {
      throw VADError.bufferSizeTooSmall
    }

    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { responseBuffer.deallocate() }

    let optionsJSON = try options.map { try String(decoding: ffiEncoder.encode($0), as: UTF8.self) }

    let result =
      switch request {
      case .audio(let audio):
        cactus_vad(
          self.model,
          audio.nativePath,
          responseBuffer,
          maxBufferSize * MemoryLayout<CChar>.stride,
          optionsJSON,
          nil,
          0
        )
      case .buffer(let pcmBuffer):
        pcmBuffer.withUnsafeBufferPointer { rawBuffer in
          cactus_vad(
            self.model,
            nil,
            responseBuffer,
            maxBufferSize * MemoryLayout<CChar>.stride,
            optionsJSON,
            rawBuffer.baseAddress,
            rawBuffer.count
          )
        }
      }

    var responseData = Data()
    for i in 0..<strnlen(responseBuffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: responseBuffer[i]))
    }

    guard result != -1 else {
      let response = try? ffiDecoder.decode(FFIErrorResponse.self, from: responseData)
      if response?.error.contains("Buffer not big enough") == true {
        throw VADError.bufferSizeTooSmall
      }
      if response?.error.localizedCaseInsensitiveContains("not supported") == true {
        throw VADError.notSupported
      }
      throw VADError.generation(message: response?.error)
    }

    return try ffiDecoder.decode(VADResult.self, from: responseData)
  }
}

extension CactusLanguageModel.VADResult: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.segments = try container.decode([CactusLanguageModel.VADSegment].self, forKey: .segments)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
  }
}

extension CactusLanguageModel.VADResult: Encodable {
  private enum CodingKeys: String, CodingKey {
    case segments
    case totalTimeMs = "total_time_ms"
    case ramUsageMb = "ram_usage_mb"
  }
}

extension CactusLanguageModel.VADOptions: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.threshold = try container.decodeIfPresent(Float.self, forKey: .threshold)
    self.negThreshold = try container.decodeIfPresent(Float.self, forKey: .negThreshold)
    self.minSpeechDuration =
      try container.decodeIfPresent(Int.self, forKey: .minSpeechDuration)
      .map {
        TimeInterval($0) / 1000
      }
    self.maxSpeechDuration =
      try container.decodeIfPresent(Double.self, forKey: .maxSpeechDuration)
      .map { seconds in
        TimeInterval(seconds)
      }
    self.minSilenceDuration =
      try container.decodeIfPresent(Int.self, forKey: .minSilenceDuration)
      .map {
        TimeInterval($0) / 1000
      }
    self.speechPadMs = try container.decodeIfPresent(Int.self, forKey: .speechPadMs)
    self.windowSizeSamples = try container.decodeIfPresent(Int.self, forKey: .windowSizeSamples)
    self.minSilenceAtMaxSpeech =
      try container.decodeIfPresent(Int.self, forKey: .minSilenceAtMaxSpeech)
    self.useMaxPossSilAtMaxSpeech =
      try container.decodeIfPresent(Bool.self, forKey: .useMaxPossSilAtMaxSpeech)
    self.samplingRate = try container.decodeIfPresent(Int.self, forKey: .samplingRate)
  }
}

extension CactusLanguageModel.VADOptions: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(self.threshold, forKey: .threshold)
    try container.encodeIfPresent(self.negThreshold, forKey: .negThreshold)
    try container.encodeIfPresent(
      self.minSpeechDuration.map { Int(($0 * 1000).rounded()) },
      forKey: .minSpeechDuration
    )
    try container.encodeIfPresent(self.maxSpeechDuration, forKey: .maxSpeechDuration)
    try container.encodeIfPresent(
      self.minSilenceDuration.map { Int(($0 * 1000).rounded()) },
      forKey: .minSilenceDuration
    )
    try container.encodeIfPresent(self.speechPadMs, forKey: .speechPadMs)
    try container.encodeIfPresent(self.windowSizeSamples, forKey: .windowSizeSamples)
    try container.encodeIfPresent(self.minSilenceAtMaxSpeech, forKey: .minSilenceAtMaxSpeech)
    try container.encodeIfPresent(
      self.useMaxPossSilAtMaxSpeech,
      forKey: .useMaxPossSilAtMaxSpeech
    )
    try container.encodeIfPresent(self.samplingRate, forKey: .samplingRate)
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

    /// The minimum confidence threshold for tool selection (0.0-1.0).
    public var confidenceThreshold: Float

    /// The number of top results for tool RAG retrieval.
    public var toolRagTopK: Int

    /// Whether to include stop sequences in the response.
    public var includeStopSequences: Bool

    /// Creates options for generating inferences.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: The temperature.
    ///   - topP: The nucleus sampling.
    ///   - topK: The k most probable options to limit the next word to.
    ///   - stopSequences: An array of stop sequence phrases.
    ///   - forceFunctions: Whether to force functions to be used by the model.
    ///   - confidenceThreshold: The minimum confidence threshold for tool selection (0.0-1.0).
    ///   - toolRagTopK: The number of top results for tool RAG retrieval.
    ///   - includeStopSequences: Whether to include stop sequences in the response.
    public init(
      maxTokens: Int = 200,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = Self.defaultStopSequences,
      forceFunctions: Bool = false,
      confidenceThreshold: Float = 0.7,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.stopSequences = stopSequences
      self.forceFunctions = forceFunctions
      self.confidenceThreshold = confidenceThreshold
      self.toolRagTopK = toolRagTopK
      self.includeStopSequences = includeStopSequences
    }

    /// Creates options for generating inferences.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - modelType: The model type.
    ///   - stopSequences: An array of stop sequence phrases.
    ///   - forceFunctions: Whether to force functions to be used by the model.
    ///   - confidenceThreshold: The minimum confidence threshold for tool selection (0.0-1.0).
    ///   - toolRagTopK: The number of top results for tool RAG retrieval.
    ///   - includeStopSequences: Whether to include stop sequences in the response.
    public init(
      maxTokens: Int = 200,
      modelType: CactusLanguageModel.ModelType,
      stopSequences: [String] = Self.defaultStopSequences,
      forceFunctions: Bool = false,
      confidenceThreshold: Float = 0.7,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false
    ) {
      self.maxTokens = maxTokens
      self.temperature = modelType.defaultTemperature
      self.topP = modelType.defaultTopP
      self.topK = modelType.defaultTopK
      self.stopSequences = stopSequences
      self.forceFunctions = forceFunctions
      self.confidenceThreshold = confidenceThreshold
      self.toolRagTopK = toolRagTopK
      self.includeStopSequences = includeStopSequences
    }

    private enum CodingKeys: String, CodingKey {
      case maxTokens = "max_tokens"
      case temperature
      case topP = "top_p"
      case topK = "top_k"
      case stopSequences = "stop_sequences"
      case forceFunctions = "force_tools"
      case confidenceThreshold = "confidence_threshold"
      case toolRagTopK = "tool_rag_top_k"
      case includeStopSequences = "include_stop_sequences"
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

// MARK: - RAG Query

extension CactusLanguageModel {
  /// A result from querying a RAG (Retrieval-Augmented Generation) corpus.
  public struct RAGQueryResult: Hashable, Sendable, Decodable, Encodable {
    /// The relevant document chunks from the corpus, sorted by relevance score.
    public let chunks: [RAGChunk]
  }

  /// A chunk from a RAG corpus with its relevance score and metadata.
  public struct RAGChunk: Hashable, Sendable, Decodable, Encodable {
    /// The relevance score of this chunk (0-1), computed using embeddings and BM25 rankings.
    public let score: Double

    /// The source file for this chunk.
    public let source: String

    /// The text content of this chunk.
    public let content: String
  }

  /// An error thrown when querying a RAG corpus.
  public enum RAGQueryError: Error, Hashable {
    /// The response buffer was too small to contain the full results.
    case bufferSizeTooSmall

    /// The model does not have a corpus index loaded.
    case ragNotSupported

    /// An error occurred during RAG retrieval.
    case generation(message: String?)
  }

  /// Queries the RAG corpus for documents relevant to the query.
  ///
  /// This method is only supported on models initialized with a corpus directory.
  ///
  /// The search is performed by combining embeddings and BM25 rankings to find the most relevant
  /// document chunks from the corpus directory that was provided during model initialization.
  ///
  /// - Parameters:
  ///   - query: The search query string to find relevant documents.
  ///   - topK: The maximum number of chunks to return (default: 10).
  ///   - maxBufferSize: The maximum buffer size for the response (default: 8192).
  /// - Returns: A ``RAGQueryResult`` containing relevant document chunks.
  public func ragQuery(
    query: String,
    topK: Int = 10,
    maxBufferSize: Int? = nil
  ) throws -> RAGQueryResult {
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else { throw RAGQueryError.bufferSizeTooSmall }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let result = cactus_rag_query(
      self.model,
      query,
      buffer,
      maxBufferSize * MemoryLayout<CChar>.stride,
      topK
    )

    var responseData = Data()
    for i in 0..<strnlen(buffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: buffer[i]))
    }

    guard result > 0 else {
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )

      if response?.error.contains("No corpus") == true {
        throw RAGQueryError.ragNotSupported
      }

      throw RAGQueryError.bufferSizeTooSmall
    }

    return try ffiDecoder.decode(RAGQueryResult.self, from: responseData)
  }
}

// MARK: - Token Callback

private func withTokenCallback<T>(
  _ callback: (String, UInt32) -> Void,
  perform operation: (UnsafeMutableRawPointer, cactus_token_callback) throws -> T
) rethrows -> T {
  try withoutActuallyEscaping(callback) { onToken in
    let box = Unmanaged.passRetained(TokenCallbackBox(onToken))
    defer { box.release() }
    return try operation(box.toOpaque()) { token, tokenId, ptr in
      guard let ptr, let token else { return }
      let box = Unmanaged<TokenCallbackBox>.fromOpaque(ptr).takeUnretainedValue()
      box.callback(String(cString: token), tokenId)
    }
  }
}

private final class TokenCallbackBox {
  let callback: (String, UInt32) -> Void

  init(_ callback: @escaping (String, UInt32) -> Void) {
    self.callback = callback
  }
}
