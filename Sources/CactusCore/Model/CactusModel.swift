import CXXCactusShims
import Foundation

// MARK: - CactusModel

/// A model powered by the cactus engine.
///
/// This type is largely not thread safe outside of calling ``stop()`` on a separate thread when
/// the model is in the process of generating a response.
///
/// All methods of this type are synchronous and blocking, and should not be called on the main
/// actor due to the long runtimes. To access the model safely in the background, use ``CactusModelActor``.
public struct CactusModel: ~Copyable {
  private static let bufferNotBigEnoughErrorMessage = "buffer too small"
  private static let unavailableModelPointerMessage = "CactusModel pointer is unavailable."

  /// The underlying model pointer.
  private var modelPointer: cactus_model_t?

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  public init(
    from url: URL,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false
  ) throws {
    guard
      let modelPointer = cactus_init(
        url.nativePath,
        corpusDirectoryURL?.nativePath,
        cacheIndex
      )
    else {
      throw CreationError(
        modelURL: url,
        corpusDirectoryURL: corpusDirectoryURL,
        cacheIndex: cacheIndex
      )
    }
    self.modelPointer = modelPointer
  }

  /// Creates a language model from the specified model pointer.
  ///
  /// - Parameters:
  ///   - model: The model pointer.
  public init(model: consuming cactus_model_t) {
    self.modelPointer = model
  }

  deinit {
    if let modelPointer {
      cactus_destroy(modelPointer)
    }
  }

  /// Provides scoped access to the underlying model pointer.
  ///
  /// - Parameter body: The operation to run with the model pointer.
  /// - Returns: The operation return value.
  public borrowing func withModelPointer<Result: ~Copyable, E: Error>(
    _ body: (cactus_model_t) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    try body(self.requiredModelPointer())
  }

  /// Transfers ownership of the underlying model pointer out of this model.
  ///
  /// After calling this method, this value no longer owns a pointer and will not
  /// destroy one during `deinit`.
  ///
  /// - Returns: The owned model pointer.
  public consuming func takeModelPointer() -> cactus_model_t {
    let modelPointer = self.requiredModelPointer()
    self.modelPointer = nil
    return modelPointer
  }

  private var rawModelPointer: cactus_model_t {
    self.requiredModelPointer()
  }

  private func requiredModelPointer() -> cactus_model_t {
    guard let modelPointer = self.modelPointer else {
      preconditionFailure(Self.unavailableModelPointerMessage)
    }
    return modelPointer
  }
}

// MARK: - Creation Error

extension CactusModel {
  /// An error thrown when trying to create a model.
  public struct CreationError: Error, Hashable {
    /// The error message.
    public let message: String

    init(
      modelURL: URL,
      corpusDirectoryURL: URL?,
      cacheIndex: Bool
    ) {
      if let message = cactus_get_last_error() {
        self.message = String(cString: message)
      } else {
        self.message =
          "Failed to create model with modelURL: \(modelURL), corpusDirectoryURL: \(String(describing: corpusDirectoryURL)), cacheIndex: \(cacheIndex)"
      }
    }
  }
}

// MARK: - CactusModel Error

/// An error thrown by ``CactusModel`` operations.
public struct CactusModelError: Error, Hashable, Sendable {
  /// A stable machine-readable error code.
  public struct Code: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    /// The buffer size for tokenized output was too small.
    public static let tokenizeBufferTooSmall = Self(rawValue: "tokenizeBufferTooSmall")

    /// An error occurred during tokenization.
    public static let tokenizeInvalidTokenization = Self(rawValue: "tokenizeInvalidTokenization")

    /// The buffer size for generated embeddings was too small.
    public static let embeddingsBufferTooSmall = Self(rawValue: "embeddingsBufferTooSmall")

    /// The model does not support image embeddings.
    public static let embeddingsImageNotSupported = Self(rawValue: "embeddingsImageNotSupported")

    /// The model does not support audio embeddings.
    public static let embeddingsAudioNotSupported = Self(rawValue: "embeddingsAudioNotSupported")

    /// An embeddings generation error.
    public static let embeddingsGeneration = Self(rawValue: "embeddingsGeneration")

    /// The buffer size for completion was too small.
    public static let completionBufferTooSmall = Self(rawValue: "completionBufferTooSmall")

    /// A completion generation error.
    public static let completionGeneration = Self(rawValue: "completionGeneration")

    /// The buffer size for transcription was too small.
    public static let transcriptionBufferTooSmall = Self(rawValue: "transcriptionBufferTooSmall")

    /// The model does not support transcription.
    public static let transcriptionNotSupported = Self(rawValue: "transcriptionNotSupported")

    /// A transcription generation error.
    public static let transcriptionGeneration = Self(rawValue: "transcriptionGeneration")

    /// The buffer size for voice activity detection was too small.
    public static let vadBufferTooSmall = Self(rawValue: "vadBufferTooSmall")

    /// The model does not support voice activity detection.
    public static let vadNotSupported = Self(rawValue: "vadNotSupported")

    /// A voice activity detection generation error.
    public static let vadGeneration = Self(rawValue: "vadGeneration")

    /// The response buffer for RAG query was too small.
    public static let ragQueryBufferTooSmall = Self(rawValue: "ragQueryBufferTooSmall")

    /// The model does not have a corpus index loaded.
    public static let ragQueryNotSupported = Self(rawValue: "ragQueryNotSupported")

    /// A RAG query generation error.
    public static let ragQueryGeneration = Self(rawValue: "ragQueryGeneration")
  }

  /// A stable machine-readable error code.
  public let code: Code

  /// Additional context for the error, when available.
  public let message: String?

  /// Creates a model error with a stable code and optional context message.
  ///
  /// - Parameters:
   ///   - code: A stable machine-readable error code.
  ///   - message: Optional additional context describing the failure.
  public init(code: Code, message: String? = nil) {
    self.code = code
    self.message = message
  }

  /// The buffer size for tokenized output was too small.
  public static let tokenizeBufferTooSmall = Self(code: .tokenizeBufferTooSmall)

  /// An error occurred during tokenization.
  public static let tokenizeInvalidTokenization = Self(code: .tokenizeInvalidTokenization)

  /// The buffer size for generated embeddings was too small.
  public static let embeddingsBufferTooSmall = Self(code: .embeddingsBufferTooSmall)

  /// The model does not support image embeddings.
  public static let embeddingsImageNotSupported = Self(code: .embeddingsImageNotSupported)

  /// The model does not support audio embeddings.
  public static let embeddingsAudioNotSupported = Self(code: .embeddingsAudioNotSupported)

  /// An embeddings generation error.
  public static func embeddingsGeneration(message: String?) -> Self {
    Self(code: .embeddingsGeneration, message: message)
  }

  /// The buffer size for completion was too small.
  public static let completionBufferTooSmall = Self(code: .completionBufferTooSmall)

  /// A completion generation error.
  public static func completionGeneration(message: String?) -> Self {
    Self(code: .completionGeneration, message: message)
  }

  /// The buffer size for transcription was too small.
  public static let transcriptionBufferTooSmall = Self(code: .transcriptionBufferTooSmall)

  /// The model does not support transcription.
  public static let transcriptionNotSupported = Self(code: .transcriptionNotSupported)

  /// A transcription generation error.
  public static func transcriptionGeneration(message: String?) -> Self {
    Self(code: .transcriptionGeneration, message: message)
  }

  /// The buffer size for voice activity detection was too small.
  public static let vadBufferTooSmall = Self(code: .vadBufferTooSmall)

  /// The model does not support voice activity detection.
  public static let vadNotSupported = Self(code: .vadNotSupported)

  /// A voice activity detection generation error.
  public static func vadGeneration(message: String?) -> Self {
    Self(code: .vadGeneration, message: message)
  }

  /// The response buffer for RAG query was too small.
  public static let ragQueryBufferTooSmall = Self(code: .ragQueryBufferTooSmall)

  /// The model does not have a corpus index loaded.
  public static let ragQueryNotSupported = Self(code: .ragQueryNotSupported)

  /// A RAG query generation error.
  public static func ragQueryGeneration(message: String?) -> Self {
    Self(code: .ragQueryGeneration, message: message)
  }
}

// MARK: - Tokenize

extension CactusModel {
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
      self.rawModelPointer,
      text,
      buffer.baseAddress,
      buffer.count,
      &tokenLength
    )
    switch resultCode {
    case -1:
      throw CactusModelError.tokenizeInvalidTokenization
    case -2:
      throw CactusModelError.tokenizeBufferTooSmall
    default:
      return tokenLength
    }
  }
}

// MARK: - Score Window

extension CactusModel {
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

    let (result, responseData) = try withFFIBuffer(bufferSize: responseBufferSize) {
      responseBuffer,
      responseBufferSize in
      cactus_score_window(
        self.rawModelPointer,
        tokens.baseAddress,
        tokens.count,
        start,
        end,
        context,
        responseBuffer,
        responseBufferSize
      )
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

extension CactusModel {
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
      throw CactusModelError.embeddingsBufferTooSmall
    }
    var dimensions = 0
    let rawBufferSize = size * MemoryLayout<Float>.stride

    let resultCode =
      switch request {
      case .text(let text, let normalize):
        cactus_embed(
          self.rawModelPointer,
          text,
          buffer.baseAddress,
          rawBufferSize,
          &dimensions,
          normalize
        )
      case .image(let image):
        cactus_image_embed(
          self.rawModelPointer,
          image.nativePath,
          buffer.baseAddress,
          rawBufferSize,
          &dimensions
        )
      case .audio(let audio):
        cactus_audio_embed(
          self.rawModelPointer,
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
        throw CactusModelError.embeddingsImageNotSupported
      } else if message?.contains("Audio embeddings") == true {
        throw CactusModelError.embeddingsAudioNotSupported
      } else {
        throw CactusModelError.embeddingsGeneration(message: message)
      }
    case -2:
      throw CactusModelError.embeddingsBufferTooSmall
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
    8192
  }
}

// MARK: - Chat Completion

extension CactusModel {
  /// A chat completion result.
  public struct Completion: Hashable, Sendable {
    /// The raw response text from the model.
    public let response: String

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// A list of ``CactusModel/FunctionCall`` instances from the model.
    public let functionCalls: [FunctionCall]

    /// The model's confidence in its response.
    public let confidence: Double

    /// The prefill tokens per second.
    public let prefillTps: Double

    /// The decode tokens per second.
    public let decodeTps: Double

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

    /// Whether this completion was handed off to cloud inference.
    public let didHandoffToCloud: Bool

    private let timeToFirstTokenMs: Double
    private let totalTimeMs: Double

    /// The amount of time to generate the first token.
    public var durationToFirstToken: Duration {
      .milliseconds(self.timeToFirstTokenMs)
    }

    /// The total generation time.
    public var totalDuration: Duration {
      .milliseconds(self.totalTimeMs)
    }
  }

  /// A completed chat turn with canonical continuation messages.
  public struct CompletedChatTurn: Hashable, Sendable {
    /// The raw completion returned by the model.
    public let completion: Completion

    /// Canonical conversation messages that include the generated assistant turn.
    public let messages: [ChatMessage]
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
    options: Completion.Options = Completion.Options(),
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
    options: Completion.Options = Completion.Options(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> CompletedChatTurn {
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else {
      throw CactusModelError.completionBufferTooSmall
    }

    let functions = functions.map { FFIFunctionDefinition(function: $0) }
    let functionsJSON =
      functions.isEmpty
      ? nil
      : String(decoding: try ffiEncoder.encode(functions), as: UTF8.self)

    let ffiMessages = messages.map { FFIMessage(message: $0) }
    var streamedResponse = ""

    let (result, responseData) = try withFFIBuffer(bufferSize: maxBufferSize) {
      buffer,
      responseBufferSize in
      try withTokenCallback { token, tokenID in
        streamedResponse += token
        onToken(token, tokenID)
      } perform: { userData, onToken in
        cactus_complete(
          self.rawModelPointer,
          String(decoding: try ffiEncoder.encode(ffiMessages), as: UTF8.self),
          buffer,
          responseBufferSize,
          String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
          functionsJSON,
          onToken,
          userData
        )
      }
    }

    guard result != -1 else {
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )
      if response?.error.contains(Self.bufferNotBigEnoughErrorMessage) == true {
        throw CactusModelError.completionBufferTooSmall
      }
      throw CactusModelError.completionGeneration(message: response?.error)
    }
    let completion = try ffiDecoder.decode(Completion.self, from: responseData)
    var completedMessages = messages
    completedMessages.append(
      .assistant(
        completion.response.count > streamedResponse.count ? completion.response : streamedResponse
      )
    )
    return CompletedChatTurn(completion: completion, messages: completedMessages)
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

extension CactusModel.Completion {
  /// Options for generating a ``CactusModel/ChatCompletion``.
  public struct Options: Hashable, Sendable {
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

    /// The minimum confidence threshold for cloud handoff (0.0-1.0).
    public var cloudHandoffThreshold: Float

    /// The number of top results for tool RAG retrieval.
    public var toolRagTopK: Int

    /// Whether to include stop sequences in the response.
    public var includeStopSequences: Bool

    /// Whether telemetry is enabled.
    public var isTelemetryEnabled: Bool

    /// Whether to automatically handoff to cloud when confidence is below threshold.
    public var autoHandoff: Bool

    /// Timeout duration for cloud handoff.
    public var cloudTimeoutDuration: Duration

    /// Whether to include images when handing off to cloud.
    public var handoffWithImages: Bool

    /// Creates options for generating chat completions.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - stopSequences: Phrases that stop generation when emitted.
    ///   - forceFunctions: Whether tool calls are forced when tools are provided.
    ///   - cloudHandoffThreshold: Confidence threshold used for cloud handoff.
    ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
    ///   - includeStopSequences: Whether stop sequences are kept in final output.
    ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
    ///   - autoHandoff: Whether to automatically handoff to cloud when confidence is below threshold.
    ///   - cloudTimeoutDuration: Timeout duration for cloud handoff.
    ///   - handoffWithImages: Whether to include images when handing off to cloud.
    public init(
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = Self.defaultStopSequences,
      forceFunctions: Bool = false,
      cloudHandoffThreshold: Float = 0.7,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false,
      isTelemetryEnabled: Bool = false,
      autoHandoff: Bool = true,
      cloudTimeoutDuration: Duration = .milliseconds(15000),
      handoffWithImages: Bool = true
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.stopSequences = stopSequences
      self.forceFunctions = forceFunctions
      self.cloudHandoffThreshold = cloudHandoffThreshold
      self.toolRagTopK = toolRagTopK
      self.includeStopSequences = includeStopSequences
      self.isTelemetryEnabled = isTelemetryEnabled
      self.autoHandoff = autoHandoff
      self.cloudTimeoutDuration = cloudTimeoutDuration
      self.handoffWithImages = handoffWithImages
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
      case isTelemetryEnabled = "telemetry_enabled"
      case autoHandoff = "auto_handoff"
      case cloudTimeoutDuration = "cloud_timeout_ms"
      case handoffWithImages = "handoff_with_images"
    }
  }
}

extension CactusModel.Completion.Options: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.maxTokens, forKey: .maxTokens)
    try container.encode(self.temperature, forKey: .temperature)
    try container.encode(self.topP, forKey: .topP)
    try container.encode(self.topK, forKey: .topK)
    try container.encode(self.stopSequences, forKey: .stopSequences)
    try container.encode(self.forceFunctions, forKey: .forceFunctions)
    try container.encode(self.cloudHandoffThreshold, forKey: .confidenceThreshold)
    try container.encode(self.toolRagTopK, forKey: .toolRagTopK)
    try container.encode(self.includeStopSequences, forKey: .includeStopSequences)
    try container.encode(self.isTelemetryEnabled, forKey: .isTelemetryEnabled)
    try container.encode(self.autoHandoff, forKey: .autoHandoff)
    try container.encode(
      self.cloudTimeoutDuration.secondsDouble * 1000,
      forKey: .cloudTimeoutDuration
    )
    try container.encode(self.handoffWithImages, forKey: .handoffWithImages)
  }
}

extension CactusModel.Completion.Options: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.maxTokens = try container.decode(Int.self, forKey: .maxTokens)
    self.temperature = try container.decode(Float.self, forKey: .temperature)
    self.topP = try container.decode(Float.self, forKey: .topP)
    self.topK = try container.decode(Int.self, forKey: .topK)
    self.stopSequences = try container.decode([String].self, forKey: .stopSequences)
    self.forceFunctions = try container.decode(Bool.self, forKey: .forceFunctions)
    self.cloudHandoffThreshold = try container.decode(Float.self, forKey: .confidenceThreshold)
    self.toolRagTopK = try container.decode(Int.self, forKey: .toolRagTopK)
    self.includeStopSequences = try container.decode(Bool.self, forKey: .includeStopSequences)
    self.isTelemetryEnabled = try container.decode(Bool.self, forKey: .isTelemetryEnabled)
    self.autoHandoff = try container.decode(Bool.self, forKey: .autoHandoff)
    self.cloudTimeoutDuration = .milliseconds(
      try container.decode(Double.self, forKey: .cloudTimeoutDuration)
    )
    self.handoffWithImages = try container.decode(Bool.self, forKey: .handoffWithImages)
  }
}

extension CactusModel.Completion: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.response = try container.decode(String.self, forKey: .response)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.functionCalls =
      try container.decodeIfPresent([CactusModel.FunctionCall].self, forKey: .functionCalls)
      ?? []
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.prefillTps = try container.decode(Double.self, forKey: .prefillTps)
    self.decodeTps = try container.decode(Double.self, forKey: .decodeTps)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
    self.didHandoffToCloud =
      try container.decodeIfPresent(Bool.self, forKey: .didHandoffToCloud) ?? false
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusModel.Completion: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.response, forKey: .response)
    try container.encode(self.prefillTokens, forKey: .prefillTokens)
    try container.encode(self.decodeTokens, forKey: .decodeTokens)
    try container.encode(self.totalTokens, forKey: .totalTokens)
    try container.encode(self.functionCalls, forKey: .functionCalls)
    try container.encode(self.confidence, forKey: .confidence)
    try container.encode(self.prefillTps, forKey: .prefillTps)
    try container.encode(self.decodeTps, forKey: .decodeTps)
    try container.encode(self.ramUsageMb, forKey: .ramUsageMb)
    try container.encode(self.didHandoffToCloud, forKey: .didHandoffToCloud)
    try container.encode(self.timeToFirstTokenMs, forKey: .timeToFirstTokenMs)
    try container.encode(self.totalTimeMs, forKey: .totalTimeMs)
  }

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
    case didHandoffToCloud = "cloud_handoff"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - Transcribe

extension CactusModel {
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

    /// Whether this transcription was handed off to cloud inference.
    public let didHandoffToCloud: Bool

    private let timeToFirstToken: Duration
    private let totalTime: Duration

    /// The amount of time to generate the first token.
    public var durationToFirstToken: Duration {
      self.timeToFirstToken
    }

    /// The total generation time.
    public var totalDuration: Duration {
      self.totalTime
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
    options: Transcription.Options = Transcription.Options(),
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
    options: Transcription.Options = Transcription.Options(),
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
    options: Transcription.Options = Transcription.Options(),
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
    options: Transcription.Options = Transcription.Options(),
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

extension CactusModel {
  private enum TranscriptionRequest {
    case audio(URL)
    case buffer([UInt8])
  }

  private func transcribe(
    for request: TranscriptionRequest,
    prompt: String,
    options: Transcription.Options = Transcription.Options(),
    maxBufferSize: Int? = nil,
    onToken: (String, UInt32) -> Void
  ) throws -> Transcription {
    let maxBufferSize = maxBufferSize ?? 8192
    guard maxBufferSize > 0 else {
      throw CactusModelError.transcriptionBufferTooSmall
    }

    let (result, responseData) = try withFFIBuffer(bufferSize: maxBufferSize) {
      buffer,
      responseBufferSize in
      try withTokenCallback(onToken) { userData, onToken in
        switch request {
        case .audio(let audio):
          return cactus_transcribe(
            self.rawModelPointer,
            audio.nativePath,
            prompt,
            buffer,
            responseBufferSize,
            String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
            onToken,
            userData,
            nil,
            0
          )
        case .buffer(let pcmBuffer):
          return try pcmBuffer.withUnsafeBufferPointer { rawBuffer in
            cactus_transcribe(
              self.rawModelPointer,
              nil,
              prompt,
              buffer,
              responseBufferSize,
              String(decoding: try ffiEncoder.encode(options), as: UTF8.self),
              onToken,
              userData,
              rawBuffer.baseAddress,
              rawBuffer.count
            )
          }
        }
      }
    }

    guard result != -1 else {
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )
      if response?.error.contains(Self.bufferNotBigEnoughErrorMessage) == true {
        throw CactusModelError.transcriptionBufferTooSmall
      }
      throw CactusModelError.transcriptionGeneration(message: response?.error)
    }
    let transcription = try ffiDecoder.decode(Transcription.self, from: responseData)
    return transcription
  }
}

extension CactusModel.Transcription {
  /// Options for generating a ``CactusModel/Transcription``.
  public struct Options: Hashable, Sendable, Codable {
    /// The maximum number of tokens for the completion.
    public var maxTokens: Int

    /// The temperature.
    public var temperature: Float

    /// The nucleus sampling.
    public var topP: Float

    /// The k most probable options to limit the next word to.
    public var topK: Int

    /// Whether telemetry is enabled.
    public var isTelemetryEnabled: Bool

    /// Whether to enable VAD weights on the transcription model.
    public var useVad: Bool?

    /// Threshold for triggering cloud handoff based on confidence.
    public var cloudHandoffThreshold: Float?

    /// Creates options for generating transcriptions.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens for the transcription.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
    ///   - useVad: Whether to enable VAD weights for transcription. `nil` defers to higher-level defaults.
    ///   - cloudHandoffThreshold: Optional confidence threshold for cloud handoff.
    public init(
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      isTelemetryEnabled: Bool = false,
      useVad: Bool? = nil,
      cloudHandoffThreshold: Float? = nil
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.isTelemetryEnabled = isTelemetryEnabled
      self.useVad = useVad
      self.cloudHandoffThreshold = cloudHandoffThreshold
    }

    private enum CodingKeys: String, CodingKey {
      case maxTokens = "max_tokens"
      case temperature
      case topP = "top_p"
      case topK = "top_k"
      case isTelemetryEnabled = "telemetry_enabled"
      case useVad = "use_vad"
      case cloudHandoffThreshold = "cloud_handoff_threshold"
    }
  }
}

extension CactusModel.Transcription: Decodable {
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
    self.didHandoffToCloud =
      try container.decodeIfPresent(Bool.self, forKey: .didHandoffToCloud) ?? false
    self.timeToFirstToken = .milliseconds(
      try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    )
    self.totalTime = .milliseconds(
      try container.decode(Double.self, forKey: .totalTimeMs)
    )
  }
}

extension CactusModel.Transcription: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.response, forKey: .response)
    try container.encode(self.prefillTokens, forKey: .prefillTokens)
    try container.encode(self.decodeTokens, forKey: .decodeTokens)
    try container.encode(self.totalTokens, forKey: .totalTokens)
    try container.encode(self.confidence, forKey: .confidence)
    try container.encode(self.prefillTps, forKey: .prefillTps)
    try container.encode(self.decodeTps, forKey: .decodeTps)
    try container.encode(self.ramUsageMb, forKey: .ramUsageMb)
    try container.encode(self.didHandoffToCloud, forKey: .didHandoffToCloud)
    try container.encode(self.timeToFirstToken.secondsDouble * 1000, forKey: .timeToFirstTokenMs)
    try container.encode(self.totalTime.secondsDouble * 1000, forKey: .totalTimeMs)
  }

  private enum CodingKeys: String, CodingKey {
    case response
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case confidence
    case prefillTps = "prefill_tps"
    case decodeTps = "decode_tps"
    case ramUsageMb = "ram_usage_mb"
    case didHandoffToCloud = "cloud_handoff"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - VAD

extension CactusModel {
  /// A detected speech segment.
  ///
  /// Indices are sample offsets in the sampling domain used by VAD.
  public struct VADSegment: Hashable, Sendable, Codable {
    /// Segment start sample index.
    public let startSampleIndex: Int

    /// Segment end sample index.
    public let endSampleIndex: Int

    private enum CodingKeys: String, CodingKey {
      case startSampleIndex = "start"
      case endSampleIndex = "end"
    }
  }

  /// A voice activity detection result.
  public struct VADResult: Hashable, Sendable {
    /// The detected speech segments.
    public let segments: [VADSegment]

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

    /// The total processing duration.
    public let totalDuration: Duration
  }

  /// Options for voice activity detection.
  public struct VADOptions: Hashable, Sendable {
    /// Detection threshold.
    public var threshold: Float?

    /// Negative threshold.
    public var negThreshold: Float?

    /// The minimum speech duration.
    public var minSpeechDuration: Duration?

    /// The maximum speech duration.
    public var maxSpeechDuration: Duration?

    /// The minimum silence duration.
    public var minSilenceDuration: Duration?

    /// The amount of padding duration to add around speech segments.
    public var speechPadDuration: Duration?

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
      minSpeechDuration: Duration? = nil,
      maxSpeechDuration: Duration? = nil,
      minSilenceDuration: Duration? = nil,
      speechPadDuration: Duration? = nil,
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
      self.speechPadDuration = speechPadDuration
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
      case speechPadDuration = "speech_pad_ms"
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
      throw CactusModelError.vadBufferTooSmall
    }

    let optionsJSON = try options.map { try String(decoding: ffiEncoder.encode($0), as: UTF8.self) }

    let (result, responseData) = try withFFIBuffer(bufferSize: maxBufferSize) {
      responseBuffer,
      responseBufferSize in
      switch request {
      case .audio(let audio):
        cactus_vad(
          self.rawModelPointer,
          audio.nativePath,
          responseBuffer,
          responseBufferSize,
          optionsJSON,
          nil,
          0
        )
      case .buffer(let pcmBuffer):
        pcmBuffer.withUnsafeBufferPointer { rawBuffer in
          cactus_vad(
            self.rawModelPointer,
            nil,
            responseBuffer,
            responseBufferSize,
            optionsJSON,
            rawBuffer.baseAddress,
            rawBuffer.count
          )
        }
      }
    }

    guard result != -1 else {
      let response = try? ffiDecoder.decode(FFIErrorResponse.self, from: responseData)
      if response?.error.contains(Self.bufferNotBigEnoughErrorMessage) == true {
        throw CactusModelError.vadBufferTooSmall
      }
      if response?.error.localizedCaseInsensitiveContains("not supported") == true {
        throw CactusModelError.vadNotSupported
      }
      throw CactusModelError.vadGeneration(message: response?.error)
    }

    return try ffiDecoder.decode(VADResult.self, from: responseData)
  }
}

extension CactusModel.VADResult: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.segments = try container.decode([CactusModel.VADSegment].self, forKey: .segments)
    self.totalDuration = .milliseconds(
      try container.decode(Double.self, forKey: .totalTimeMs)
    )
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
  }
}

extension CactusModel.VADResult: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.segments, forKey: .segments)
    try container.encode(self.totalDuration.secondsDouble * 1000, forKey: .totalTimeMs)
    try container.encode(self.ramUsageMb, forKey: .ramUsageMb)
  }

  private enum CodingKeys: String, CodingKey {
    case segments
    case totalTimeMs = "total_time_ms"
    case ramUsageMb = "ram_usage_mb"
  }
}

extension CactusModel.VADOptions: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.threshold = try container.decodeIfPresent(Float.self, forKey: .threshold)
    self.negThreshold = try container.decodeIfPresent(Float.self, forKey: .negThreshold)
    self.minSpeechDuration =
      try container.decodeIfPresent(Int.self, forKey: .minSpeechDuration)
      .map(Duration.milliseconds)
    self.maxSpeechDuration =
      try container.decodeIfPresent(Double.self, forKey: .maxSpeechDuration)
      .map(Duration.seconds)
    self.minSilenceDuration =
      try container.decodeIfPresent(Int.self, forKey: .minSilenceDuration)
      .map(Duration.milliseconds)
    self.speechPadDuration =
      try container.decodeIfPresent(Int.self, forKey: .speechPadDuration)
      .map(Duration.milliseconds)
    self.windowSizeSamples = try container.decodeIfPresent(Int.self, forKey: .windowSizeSamples)
    self.minSilenceAtMaxSpeech =
      try container.decodeIfPresent(Int.self, forKey: .minSilenceAtMaxSpeech)
    self.useMaxPossSilAtMaxSpeech =
      try container.decodeIfPresent(Bool.self, forKey: .useMaxPossSilAtMaxSpeech)
    self.samplingRate = try container.decodeIfPresent(Int.self, forKey: .samplingRate)
  }
}

extension CactusModel.VADOptions: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(self.threshold, forKey: .threshold)
    try container.encodeIfPresent(self.negThreshold, forKey: .negThreshold)
    try container.encodeIfPresent(
      self.minSpeechDuration.map { Int(($0.secondsDouble * 1000).rounded()) },
      forKey: .minSpeechDuration
    )
    try container.encodeIfPresent(
      self.maxSpeechDuration.map(\.secondsDouble),
      forKey: .maxSpeechDuration
    )
    try container.encodeIfPresent(
      self.minSilenceDuration.map { Int(($0.secondsDouble * 1000).rounded()) },
      forKey: .minSilenceDuration
    )
    try container.encodeIfPresent(
      self.speechPadDuration.map { Int(($0.secondsDouble * 1000).rounded()) },
      forKey: .speechPadDuration
    )
    try container.encodeIfPresent(self.windowSizeSamples, forKey: .windowSizeSamples)
    try container.encodeIfPresent(self.minSilenceAtMaxSpeech, forKey: .minSilenceAtMaxSpeech)
    try container.encodeIfPresent(
      self.useMaxPossSilAtMaxSpeech,
      forKey: .useMaxPossSilAtMaxSpeech
    )
    try container.encodeIfPresent(self.samplingRate, forKey: .samplingRate)
  }
}

// MARK: - Stop

extension CactusModel {
  /// Stops generation of an active chat completion.
  ///
  /// This method is safe to call from other threads.
  public func stop() {
    cactus_stop(self.rawModelPointer)
  }
}

// MARK: - Reset

extension CactusModel {
  /// Resets the context state of the model.
  public func reset() {
    cactus_reset(self.rawModelPointer)
  }
}

// MARK: - RAG Query

extension CactusModel {
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
    guard maxBufferSize > 0 else { throw CactusModelError.ragQueryBufferTooSmall }

    let (result, responseData) = try withFFIBuffer(bufferSize: maxBufferSize) {
      buffer,
      responseBufferSize in
      cactus_rag_query(
        self.rawModelPointer,
        query,
        buffer,
        responseBufferSize,
        topK
      )
    }

    guard result > 0 else {
      let response = try? ffiDecoder.decode(
        FFIErrorResponse.self,
        from: responseData
      )

      if response?.error.contains("No corpus") == true {
        throw CactusModelError.ragQueryNotSupported
      }

      throw CactusModelError.ragQueryBufferTooSmall
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
