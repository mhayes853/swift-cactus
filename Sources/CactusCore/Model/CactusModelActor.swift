import CXXCactusShims
import Foundation

// MARK: - CactusModelActor

/// An actor that isolates a ``CactusModel``.
///
/// This actor wraps a ``CactusModel`` to provide thread-safe and background access to a
/// language model.
///
/// ```swift
/// let actor = try await CactusModelActor(from: modelURL)
///
/// let completion = try await actor.complete(
///   messages: [
///     .system("You are a helpful assistant."),
///     .user("What is Swift?")
///   ]
/// )
/// print(completion.completion.response)
/// ```
public actor CactusModelActor {
  /// The underlying language model.
  public let model: CactusModel

  /// The ``CactusModel/Configuration`` for this model.
  public let configuration: CactusModel.Configuration

  /// The ``CactusModel/ConfigurationFile`` for this model.
  public let configurationFile: CactusModel.ConfigurationFile

  /// The custom `SerialExecutor` used by this actor, if provided.
  public let executor: (any SerialExecutor)?

  private let defaultExecutor: DefaultActorExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    if let executor {
      return executor.asUnownedSerialExecutor()
    }
    return self.defaultExecutor.unownedExecutor
  }

  /// Creates an actor from an existing language model.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - model: The underlying language model.
  public init(executor: (any SerialExecutor)? = nil, model: consuming sending CactusModel) {
    let configuration = model.configuration
    let configurationFile = model.configurationFile
    self.executor = executor
    self.model = consume model
    self.configuration = configuration
    self.configurationFile = configurationFile
    self.defaultExecutor = DefaultActorExecutor()
  }

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - url: The local `URL` of the model.
  ///   - modelSlug: The model slug.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  public init(
    executor: (any SerialExecutor)? = nil,
    from url: URL,
    modelSlug: String? = nil,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false
  ) throws {
    let model = try CactusModel(
      from: url,
      modelSlug: modelSlug,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    self.init(executor: executor, model: model)
  }

  /// Loads a model from the specified ``CactusModel/Configuration``.
  ///
  /// - Parameters:
  ///   - executor: A custom serial executor to use for this actor. If `nil`, uses the default.
  ///   - configuration: The ``Configuration``.
  public init(
    executor: (any SerialExecutor)? = nil,
    configuration: CactusModel.Configuration
  ) throws {
    let model = try CactusModel(configuration: configuration)
    self.init(executor: executor, model: model)
  }

  /// Creates a language model from the specified model pointer and configuration.
  ///
  /// The configuration must accurately represent the underlying properties of the model pointer.
  ///
  /// The memory for the model pointer is managed by the language model.
  ///
  /// - Parameters:
  ///   - executor: A custom serial executor to use for this actor. If `nil`, uses the default.
  ///   - model: The model pointer.
  ///   - configuration: A ``Configuration`` that must accurately represent the model.
  public init(
    executor: (any SerialExecutor)? = nil,
    model: consuming sending cactus_model_t,
    configuration: CactusModel.Configuration
  ) throws {
    let languageModel = try CactusModel(model: model, configuration: configuration)
    self.init(executor: executor, model: languageModel)
  }
}

// MARK: - Tokenize

extension CactusModelActor {
  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - maxBufferSize: The maximum buffer size for the tokenized output.
  /// - Returns: An array of raw tokens.
  public func tokenize(text: String, maxBufferSize: Int = 8192) async throws -> [UInt32] {
    try self.model.tokenize(text: text, maxBufferSize: maxBufferSize)
  }

  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - buffer: The buffer to store the tokenized output.
  /// - Returns: The total number of tokens.
  @discardableResult
  public func tokenize(text: String, buffer: inout MutableSpan<UInt32>) async throws -> Int {
    try self.model.tokenize(text: text, buffer: &buffer)
  }
}

// MARK: - Score Window

extension CactusModelActor {
  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``CactusModel/TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: [UInt32],
    range: Range<Int>? = nil,
    context: Int
  ) async throws -> CactusModel.TokenWindowScore {
    try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
  }

  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``CactusModel/TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: Span<UInt32>,
    range: Range<Int>? = nil,
    context: Int
  ) async throws -> CactusModel.TokenWindowScore {
    try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
  }
}

// MARK: - Embeddings

extension CactusModelActor {
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
  ) async throws -> [Float] {
    try self.model.embeddings(for: text, maxBufferSize: maxBufferSize, normalize: normalize)
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
  ) async throws -> Int {
    try self.model.embeddings(for: text, buffer: &buffer, normalize: normalize)
  }

  /// Generates embeddings for the specified `image`.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func imageEmbeddings(for image: URL, maxBufferSize: Int? = nil) async throws -> [Float] {
    try self.model.imageEmbeddings(for: image, maxBufferSize: maxBufferSize)
  }

  /// Generates embeddings for the specified `image` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - buffer: A `MutableSpan` buffer.
  /// - Returns: The number of dimensions.
  @discardableResult
  public func imageEmbeddings(
    for image: URL,
    buffer: inout MutableSpan<Float>
  ) async throws -> Int {
    try self.model.imageEmbeddings(for: image, buffer: &buffer)
  }

  /// Generates embeddings for the specified `audio`.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func audioEmbeddings(for audio: URL, maxBufferSize: Int? = nil) async throws -> [Float] {
    try self.model.audioEmbeddings(for: audio, maxBufferSize: maxBufferSize)
  }

  /// Generates embeddings for the specified `audio` and stores them in the specified buffer.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - buffer: A `MutableSpan` buffer.
  /// - Returns: The number of dimensions.
  @discardableResult
  public func audioEmbeddings(
    for audio: URL,
    buffer: inout MutableSpan<Float>
  ) async throws -> Int {
    try self.model.audioEmbeddings(for: audio, buffer: &buffer)
  }
}

// MARK: - Chat Completion

extension CactusModelActor {
  /// Generates a completed chat turn with reusable continuation messages.
  ///
  /// This API returns both the completion payload and a canonical `messages` array that includes
  /// the generated assistant response, making it suitable for direct reuse in subsequent calls.
  ///
  /// ```swift
  /// let first = try await actor.complete(
  ///   messages: [
  ///     .system("You are a concise assistant."),
  ///     .user("Summarize Swift actors in one sentence.")
  ///   ]
  /// )
  ///
  /// let second = try await actor.complete(
  ///   messages: first.messages + [.user("Now make it even shorter.")]
  /// )
  /// print(second.completion.response)
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusModel/ChatMessage`` instances.
  ///   - options: The ``CactusModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusModel.ChatMessage],
    options: CactusModel.Completion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.CompletedChatTurn {
    try self.model.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a completed chat turn with reusable continuation messages.
  ///
  /// ```swift
  /// let turn = try await actor.complete(
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
  ///   - messages: The list of ``CactusModel/ChatMessage`` instances.
  ///   - options: The ``CactusModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusModel.ChatMessage],
    options: CactusModel.Completion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.CompletedChatTurn {
    try self.model.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }
}

// MARK: - Transcribe

extension CactusModelActor {
  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusModel.Transcription.Options? = nil,
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.Transcription {
    try self.model.transcribe(
      buffer: buffer,
      prompt: prompt,
      options: options,
      transcriptionMaxBufferSize: transcriptionMaxBufferSize,
      onToken: onToken
    )
  }

  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusModel.Transcription.Options? = nil,
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.Transcription {
    try self.model.transcribe(
      buffer: buffer,
      prompt: prompt,
      options: options,
      transcriptionMaxBufferSize: transcriptionMaxBufferSize,
      onToken: onToken
    )
  }

  /// Transcribes the specified `audio` file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    audio: URL,
    prompt: String,
    options: CactusModel.Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.Transcription {
    try self.model.transcribe(
      audio: audio,
      prompt: prompt,
      options: options,
      maxBufferSize: maxBufferSize,
      onToken: onToken
    )
  }

  /// Transcribes the specified `audio` file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    audio: URL,
    prompt: String,
    options: CactusModel.Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.Transcription {
    try self.model.transcribe(
      audio: audio,
      prompt: prompt,
      options: options,
      maxBufferSize: maxBufferSize,
      onToken: onToken
    )
  }
}

// MARK: - VAD

extension CactusModelActor {
  /// Runs voice activity detection on an audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``CactusModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/VADResult``.
  public func vad(
    audio: URL,
    options: CactusModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.VADResult {
    try self.model.vad(audio: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``CactusModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/VADResult``.
  public func vad(
    pcmBuffer: [UInt8],
    options: CactusModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.VADResult {
    try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``CactusModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/VADResult``.
  public func vad(
    pcmBuffer: sending UnsafeBufferPointer<UInt8>,
    options: CactusModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.VADResult {
    try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Stop

extension CactusModelActor {
  /// Stops generation of an active chat completion.
  ///
  /// This method is safe to call from other threads.
  public func stop() async {
    self.model.stop()
  }
}

// MARK: - Reset

extension CactusModelActor {
  /// Resets the context state of the model.
  public func reset() async {
    self.model.reset()
  }
}

// MARK: - RAG Query

extension CactusModelActor {
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
  /// - Returns: A ``CactusModel/RAGQueryResult`` containing relevant document chunks.
  public func ragQuery(
    query: String,
    topK: Int = 10,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.RAGQueryResult {
    try self.model.ragQuery(query: query, topK: topK, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Exclusive Access

extension CactusModelActor {
  /// Provides exclusive access to the underlying language model.
  ///
  /// This method allows direct synchronous and exclusive access to the ``CactusModel``. The
  ///
  /// ```swift
  /// let result = try await actor.withLanguageModelAccess { model in
  ///   // ...
  /// }
  /// ```
  ///
  /// - Parameter operation: An operation to run with the model.
  /// - Returns: The operation return value.
  public func withLanguageModel<T: ~Copyable, E: Error>(
    _ operation: (borrowing CactusModel) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try operation(self.model)
  }

  /// Provides scoped access to the underlying model pointer.
  ///
  /// - Parameter operation: An operation to run with the model pointer.
  /// - Returns: The operation return value.
  public func withModelPointer<T: ~Copyable, E: Error>(
    _ operation: (cactus_model_t) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try self.model.withModelPointer(operation)
  }
}
