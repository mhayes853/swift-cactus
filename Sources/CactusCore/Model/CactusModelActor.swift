import CXXCactusShims
import Foundation

// MARK: - CactusModelActor

/// An actor that isolates a ``CactusModel``.
///
/// This actor wraps a ``CactusModel`` to provide thread-safe and background access to a
/// language model.
///
/// ```swift
/// let model = try CactusModelActor(from: modelURL)
///
/// let turn = try await model.complete(
///   messages: [
///     .system("You are a helpful assistant."),
///     .user("What is the meaning of life?")
///   ]
/// ) { token, tokenId in
///   print(token, tokenId) // Streaming
/// }
/// print(turn.response)
///
/// let transcription = try await model.transcribe(
///   audio: wavURL,
///   prompt: ""
/// ) { token, tokenId in
///   print(token, tokenId) // Streaming
/// }
/// print(transcription.response)
/// ```
public actor CactusModelActor {
  /// The underlying language model.
  public let model: CactusModel

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
    self.executor = executor
    self.model = consume model
    self.defaultExecutor = DefaultActorExecutor()
  }

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - url: The local `URL` of the model.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  public init(
    executor: (any SerialExecutor)? = nil,
    from url: URL,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false
  ) throws {
    try Task.checkCancellation()
    let model = try CactusModel(
      from: url,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    self.init(executor: executor, model: model)
  }

  /// Creates a language model from the specified model pointer.
  ///
  /// The memory for the model pointer is managed by the language model.
  ///
  /// - Parameters:
  ///   - executor: A custom serial executor to use for this actor. If `nil`, uses the default.
  ///   - model: The model pointer.
  public init(
    executor: (any SerialExecutor)? = nil,
    model: consuming sending cactus_model_t
  ) {
    let languageModel = CactusModel(model: model)
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
    try Task.checkCancellation()
    return try self.model.tokenize(text: text, maxBufferSize: maxBufferSize)
  }

  /// Tokenizes the specified `text`.
  ///
  /// - Parameters:
  ///   - text: The text to tokenize.
  ///   - buffer: The buffer to store the tokenized output.
  /// - Returns: The total number of tokens.
  @discardableResult
  public func tokenize(text: String, buffer: inout MutableSpan<UInt32>) async throws -> Int {
    try Task.checkCancellation()
    return try self.model.tokenize(text: text, buffer: &buffer)
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
    try Task.checkCancellation()
    return try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
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
    try Task.checkCancellation()
    return try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
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
    try Task.checkCancellation()
    return try self.model.embeddings(for: text, maxBufferSize: maxBufferSize, normalize: normalize)
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
    try Task.checkCancellation()
    return try self.model.embeddings(for: text, buffer: &buffer, normalize: normalize)
  }

  /// Generates embeddings for the specified `image`.
  ///
  /// - Parameters:
  ///   - image: The path of the image to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func imageEmbeddings(for image: URL, maxBufferSize: Int? = nil) async throws -> [Float] {
    try Task.checkCancellation()
    return try self.model.imageEmbeddings(for: image, maxBufferSize: maxBufferSize)
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
    try Task.checkCancellation()
    return try self.model.imageEmbeddings(for: image, buffer: &buffer)
  }

  /// Generates embeddings for the specified `audio`.
  ///
  /// - Parameters:
  ///   - audio: The `URL` of the audio file to generate embeddings for.
  ///   - maxBufferSize: The size of the buffer to allocate to store the embeddings.
  /// - Returns: An array of float values.
  public func audioEmbeddings(for audio: URL, maxBufferSize: Int? = nil) async throws -> [Float] {
    try Task.checkCancellation()
    return try self.model.audioEmbeddings(for: audio, maxBufferSize: maxBufferSize)
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
    try Task.checkCancellation()
    return try self.model.audioEmbeddings(for: audio, buffer: &buffer)
  }
}

// MARK: - Cancellation Helpers

extension CactusModelActor {
  func performStoppableGeneration<T>(
    _ operation: () throws -> T
  ) async throws -> T {
    try Task.checkCancellation()
    let modelStopper = self.model.withModelPointer { modelPointer in
      CactusModelStopper(modelPointer: modelPointer)
    }
    return try await withTaskCancellationHandler {
      do {
        let value = try operation()
        try Task.checkCancellation()
        return value
      } catch {
        if Task.isCancelled {
          throw CancellationError()
        }
        throw error
      }
    } onCancel: {
      modelStopper.stop()
    }
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
  ///   - messages: The list of ``CactusModel/Message`` instances.
  ///   - options: The ``CactusModel/Completion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
  ///   - pcmBuffer: An optional PCM buffer to include with the messages.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusModel.Message],
    options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
    maxBufferSize: Int? = nil,
    functions: [CactusModel.FunctionDefinition] = [],
    pcmBuffer: [UInt8]? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.CompletedChatTurn {
    try await self.performStoppableGeneration {
      try self.model.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: pcmBuffer,
        onToken: onToken
      )
    }
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
  ///   - messages: The list of ``CactusModel/Message`` instances.
  ///   - options: The ``CactusModel/Completion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
  ///   - pcmBuffer: An optional PCM buffer to include with the messages.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusModel.Message],
    options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
    maxBufferSize: Int? = nil,
    functions: [CactusModel.FunctionDefinition] = [],
    pcmBuffer: [UInt8]? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.CompletedChatTurn {
    try await self.performStoppableGeneration {
      try self.model.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: pcmBuffer,
        onToken: onToken
      )
    }
  }
}

// MARK: - Transcribe

extension CactusModelActor {
  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe in 16 kHz mono signed 16-bit PCM byte format.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.Transcription {
    try await self.performStoppableGeneration {
      try self.model.transcribe(
        buffer: buffer,
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }
  }

  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe in 16 kHz mono signed 16-bit PCM byte format.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.Transcription {
    try await self.performStoppableGeneration {
      try self.model.transcribe(
        buffer: buffer,
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }
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
    options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusModel.Transcription {
    try await self.performStoppableGeneration {
      try self.model.transcribe(
        audio: audio,
        prompt: prompt,
        options: options,
        maxBufferSize: maxBufferSize,
        onToken: onToken
      )
    }
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
    options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusModel.Transcription {
    try await self.performStoppableGeneration {
      try self.model.transcribe(
        audio: audio,
        prompt: prompt,
        options: options,
        maxBufferSize: maxBufferSize,
        onToken: onToken
      )
    }
  }
}

// MARK: - Language Detection

extension CactusModelActor {
  /// Detects the language from an audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``CactusModel/LanguageDetectionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/LanguageDetection``.
  public func detectLanguage(
    audio: URL,
    options: CactusModel.LanguageDetectionOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.LanguageDetection {
    try Task.checkCancellation()
    return try self.model.detectLanguage(audio: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Detects the language from a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze in 16 kHz mono signed 16-bit format.
  ///   - options: The ``CactusModel/LanguageDetectionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/LanguageDetection``.
  public func detectLanguage(
    pcmBuffer: [UInt8],
    options: CactusModel.LanguageDetectionOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.LanguageDetection {
    try Task.checkCancellation()
    return try self.model.detectLanguage(
      pcmBuffer: pcmBuffer,
      options: options,
      maxBufferSize: maxBufferSize
    )
  }

  /// Detects the language from a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze in 16 kHz mono signed 16-bit format.
  ///   - options: The ``CactusModel/LanguageDetectionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/LanguageDetection``.
  public func detectLanguage(
    pcmBuffer: sending UnsafeBufferPointer<UInt8>,
    options: CactusModel.LanguageDetectionOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.LanguageDetection {
    try Task.checkCancellation()
    return try self.model.detectLanguage(
      pcmBuffer: pcmBuffer,
      options: options,
      maxBufferSize: maxBufferSize
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
    try Task.checkCancellation()
    return try self.model.vad(audio: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze in 16 kHz mono signed 16-bit format.
  ///   - options: The ``CactusModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusModel/VADResult``.
  public func vad(
    pcmBuffer: [UInt8],
    options: CactusModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.VADResult {
    try Task.checkCancellation()
    return try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
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
    try Task.checkCancellation()
    return try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
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
    try Task.checkCancellation()
    return try self.model.ragQuery(query: query, topK: topK, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Prefill

extension CactusModelActor {
  /// Pre-populates the KV cache with the provided messages without generating output tokens.
  ///
  /// This reduces latency for future calls to ``complete(messages:options:maxBufferSize:functions:onToken:)-6umrm``
  /// by pre-filling the attention cache with the provided context.
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusModel/Message`` instances to prefill.
  ///   - options: The ``CactusModel/Completion/Options``.
  ///   - maxBufferSize: The maximum buffer size for the response.
  ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
  /// - Returns: A ``CactusModel/PrefillResult``.
  public func prefill(
    messages: [CactusModel.Message],
    options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
    maxBufferSize: Int? = nil,
    functions: [CactusModel.FunctionDefinition] = []
  ) async throws -> CactusModel.PrefillResult {
    try Task.checkCancellation()
    return try self.model.prefill(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    )
  }
}

// MARK: - Diarization

extension CactusModelActor {
  /// Runs speaker diarization on the specified audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``CactusModel/DiarizationOptions``.
  ///   - maxBufferSize: The maximum buffer size for the response.
  /// - Returns: A ``CactusModel/DiarizationResult``.
  public func diarize(
    audio: URL,
    options: CactusModel.DiarizationOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.DiarizationResult {
    try Task.checkCancellation()
    return try self.model.diarize(audio: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs speaker diarization on the specified PCM buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze in 16 kHz mono signed 16-bit format.
  ///   - options: The ``CactusModel/DiarizationOptions``.
  ///   - maxBufferSize: The maximum buffer size for the response.
  /// - Returns: A ``CactusModel/DiarizationResult``.
  public func diarize(
    pcmBuffer: [UInt8],
    options: CactusModel.DiarizationOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusModel.DiarizationResult {
    try Task.checkCancellation()
    return try self.model.diarize(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Speaker Embeddings

extension CactusModelActor {
  /// Extracts speaker embeddings from the specified audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``CactusModel/SpeakerEmbeddingsOptions``.
  ///   - maxBufferSize: The maximum buffer size for the response.
  /// - Returns: A speaker embedding vector.
  public func speakerEmbeddings(
    for audio: URL,
    options: CactusModel.SpeakerEmbeddingsOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> [Float] {
    try Task.checkCancellation()
    return try self.model.speakerEmbeddings(for: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Extracts speaker embeddings from the specified PCM buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze in 16 kHz mono signed 16-bit format.
  ///   - options: The ``CactusModel/SpeakerEmbeddingsOptions``.
  ///   - maxBufferSize: The maximum buffer size for the response.
  /// - Returns: A speaker embedding vector.
  public func speakerEmbeddings(
    pcmBuffer: [UInt8],
    options: CactusModel.SpeakerEmbeddingsOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> [Float] {
    try Task.checkCancellation()
    return try self.model.speakerEmbeddings(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
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
