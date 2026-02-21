import CXXCactusShims
import Foundation

// MARK: - CactusLanguageModelActor

/// A thread-safe actor that provides async access to a ``CactusLanguageModel``.
///
/// This actor wraps a ``CactusLanguageModel`` and provides thread-safe access through Swift's
/// actor isolation model. All methods are async to ensure they are dispatched to a background
/// thread, preventing blocking on the main thread.
///
/// ```swift
/// let actor = try await CactusLanguageModelActor(from: modelURL)
///
/// let completion = try await actor.complete(
///   messages: [
///     .system("You are a helpful assistant."),
///     .user("What is Swift?")
///   ]
/// )
/// print(completion.completion.response)
/// ```
public actor CactusLanguageModelActor {
  private let model: CactusLanguageModel

  /// The ``CactusLanguageModel/Configuration`` for this model.
  public var configuration: CactusLanguageModel.Configuration {
    self.model.configuration
  }

  /// The ``CactusLanguageModel/ConfigurationFile`` for this model.
  public var configurationFile: CactusLanguageModel.ConfigurationFile {
    self.model.configurationFile
  }

  /// Creates an actor from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: sending CactusLanguageModel) {
    self.model = model
  }

  /// Loads a model from the specified `URL`.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - modelSlug: The model slug.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  public init(
    from url: URL,
    modelSlug: String? = nil,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false
  ) throws {
    self.model = try CactusLanguageModel(
      from: url,
      modelSlug: modelSlug,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
  }

  /// Loads a model from the specified ``CactusLanguageModel/Configuration``.
  ///
  /// - Parameter configuration: The ``Configuration``.
  public init(configuration: CactusLanguageModel.Configuration) throws {
    self.model = try CactusLanguageModel(configuration: configuration)
  }

  /// Creates a language model from the specified model pointer and configuration.
  ///
  /// The configuration must accurately represent the underlying properties of the model pointer.
  ///
  /// The memory for the model pointer is managed by the language model.
  ///
  /// - Parameters:
  ///   - model: The model pointer.
  ///   - configuration: A ``Configuration`` that must accurately represent the model.
  public init(
    model: sending cactus_model_t,
    configuration: CactusLanguageModel.Configuration
  ) throws {
    self.model = try CactusLanguageModel(
      model: model,
      configuration: configuration,
      isModelPointerManaged: true
    )
  }
}

// MARK: - Tokenize

extension CactusLanguageModelActor {
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

extension CactusLanguageModelActor {
  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``CactusLanguageModel/TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: [UInt32],
    range: Range<Int>? = nil,
    context: Int
  ) async throws -> CactusLanguageModel.TokenWindowScore {
    try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
  }

  /// Calculates the log probability score of a token window.
  ///
  /// - Parameters:
  ///   - tokens: The tokens to score.
  ///   - range: The subrange of tokens to score.
  ///   - context: The amount of tokens to use as context for scoring.
  /// - Returns: ``CactusLanguageModel/TokenWindowScore``.
  public func scoreTokenWindow(
    tokens: Span<UInt32>,
    range: Range<Int>? = nil,
    context: Int
  ) async throws -> CactusLanguageModel.TokenWindowScore {
    try self.model.scoreTokenWindow(tokens: tokens, range: range, context: context)
  }
}

// MARK: - Embeddings

extension CactusLanguageModelActor {
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

extension CactusLanguageModelActor {
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
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - options: The ``CactusLanguageModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusLanguageModel.ChatMessage],
    options: CactusLanguageModel.ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusLanguageModel.CompletedChatTurn {
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
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - options: The ``CactusLanguageModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func complete(
    messages: [CactusLanguageModel.ChatMessage],
    options: CactusLanguageModel.ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusLanguageModel.CompletedChatTurn {
    try self.model.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }
}

// MARK: - Stream Complete

extension CactusLanguageModelActor {
  /// Generates a completed chat turn with parser-driven partial updates.
  ///
  /// ```swift
  /// let parser = CactusLanguageModel.StreamParsingTokenParser(
  ///   streamParser: JSONStreamParser<MyPartial>(configuration: .init())
  /// )
  ///
  /// let completed = try await actor.streamComplete(
  ///   messages: [.user("Return JSON")],
  ///   parser: parser
  /// ) { _, partial in
  ///   print(partial)
  /// }
  /// print(completed.completion.response)
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - parser: The parser used to incrementally derive partial values from generated tokens.
  ///   - options: The ``CactusLanguageModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func streamComplete<Parser: CactusLanguageModel.TokenParser>(
    messages: [CactusLanguageModel.ChatMessage],
    parser: Parser,
    options: CactusLanguageModel.ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, Parser.Partial?) -> Void = { _, _ in }
  ) async throws -> CactusLanguageModel.CompletedChatTurn {
    try self.model.streamComplete(
      messages: messages,
      parser: parser,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a completed chat turn with parser-driven partial updates.
  ///
  /// ```swift
  /// let parser = CactusLanguageModel.StreamParsingTokenParser(
  ///   streamParser: JSONStreamParser<MyPartial>(configuration: .init())
  /// )
  ///
  /// let completed = try await actor.streamComplete(
  ///   messages: [.user("Return JSON")],
  ///   parser: parser
  /// ) { _, _, partial in
  ///   print(partial)
  /// }
  /// print(completed.messages.count)
  /// ```
  ///
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - parser: The parser used to incrementally derive partial values from generated tokens.
  ///   - options: The ``CactusLanguageModel/ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Throws: Any parser error thrown while processing generated tokens.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func streamComplete<Parser: CactusLanguageModel.TokenParser>(
    messages: [CactusLanguageModel.ChatMessage],
    parser: Parser,
    options: CactusLanguageModel.ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32, Parser.Partial?) -> Void
  ) async throws -> CactusLanguageModel.CompletedChatTurn {
    try self.model.streamComplete(
      messages: messages,
      parser: parser,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }
}

// MARK: - JSON Complete

extension CactusLanguageModelActor {
  /// Generates a ``CactusLanguageModel/JSONCompletedChatTurn`` with a required schema parameter.
  ///
  /// Use this method when you want to generate structured JSON output for any `Decodable` type,
  /// but need to provide the JSON schema explicitly at the callsite.
  ///
  /// The output may fail to parse when the model emits function calls instead of final content, or
  /// when the final response does not contain valid JSON matching the target schema.
  ///
  /// ```swift
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// let schema = JSONSchema.object(
  ///   properties: [
  ///     "title": .string(),
  ///     "servings": .integer(minimum: 1)
  ///   ],
  ///   required: ["title", "servings"]
  /// )
  ///
  /// let completion = try await actor.jsonComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   schema: schema
  /// )
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonComplete<Output: Decodable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a ``CactusLanguageModel/JSONCompletedChatTurn`` with a required schema parameter.
  ///
  /// Use this method when you want to generate structured JSON output for any `Decodable` type,
  /// but need to provide the JSON schema explicitly at the callsite.
  ///
  /// The output may fail to parse when the model emits function calls instead of final content, or
  /// when the final response does not contain valid JSON matching the target schema.
  ///
  /// ```swift
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// let schema = JSONSchema.object(
  ///   properties: [
  ///     "title": .string(),
  ///     "servings": .integer(minimum: 1)
  ///   ],
  ///   required: ["title", "servings"]
  /// )
  ///
  /// let completion = try await actor.jsonComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   schema: schema
  /// )
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonComplete<Output: Decodable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a streamable ``CactusLanguageModel/JSONCompletedChatTurn`` with a required schema parameter.
  ///
  /// Use this method when you want to generate streaming structured JSON output for any
  /// `Decodable & StreamParseable` type, but need to provide the JSON schema explicitly
  /// at the callsite.
  ///
  /// During streaming, partial values are best-effort and may be `nil` when no parseable JSON
  /// fragment is available for a token.
  ///
  /// ```swift
  /// @StreamParseable
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// extension Recipe.Partial: Encodable {}
  ///
  /// let schema = JSONSchema.object(
  ///   properties: [
  ///     "title": .string(),
  ///     "servings": .integer(minimum: 1)
  ///   ],
  ///   required: ["title", "servings"]
  /// )
  ///
  /// let completion = try await actor.jsonStreamableComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   schema: schema
  /// ) { _, _, partial in
  ///   if let partial {
  ///     print("\nPartial: \(partial)")
  ///   }
  /// }
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: Decodable & StreamParseable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, Output.Partial?) -> Void = { _, _ in }
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output>
  where Output.Partial: Sendable {
    try self.model.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a streamable ``CactusLanguageModel/JSONCompletedChatTurn`` with a required schema parameter.
  ///
  /// Use this method when you want to generate streaming structured JSON output for any
  /// `Decodable & StreamParseable` type, but need to provide the JSON schema explicitly
  /// at the callsite.
  ///
  /// During streaming, partial values are best-effort and may be `nil` when no parseable JSON
  /// fragment is available for a token.
  ///
  /// ```swift
  /// @StreamParseable
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// extension Recipe.Partial: Encodable {}
  ///
  /// let schema = JSONSchema.object(
  ///   properties: [
  ///     "title": .string(),
  ///     "servings": .integer(minimum: 1)
  ///   ],
  ///   required: ["title", "servings"]
  /// )
  ///
  /// let completion = try await actor.jsonStreamableComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   schema: schema
  /// ) { _, _, partial in
  ///   if let partial {
  ///     print("\nPartial: \(partial)")
  ///   }
  /// }
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: Decodable & StreamParseable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32, Output.Partial?) -> Void
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a ``CactusLanguageModel/JSONCompletedChatTurn`` for any ``JSONGenerable`` output type.
  ///
  /// The output may fail to parse when the model emits function calls instead of final content, or
  /// when the final response does not contain valid JSON matching the target schema.
  ///
  /// ```swift
  /// @JSONSchema
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// let completion = try await actor.jsonComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self
  /// )
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonComplete<Output: JSONGenerable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type = Output.self,
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonComplete(
      messages: messages,
      as: outputType,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a ``CactusLanguageModel/JSONCompletedChatTurn`` for any ``JSONGenerable`` output type.
  ///
  /// The output may fail to parse when the model emits function calls instead of final content, or
  /// when the final response does not contain valid JSON matching the target schema.
  ///
  /// ```swift
  /// @JSONSchema
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// let completion = try await actor.jsonComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self
  /// )
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonComplete<Output: JSONGenerable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type = Output.self,
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonComplete(
      messages: messages,
      as: outputType,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a streamable ``CactusLanguageModel/JSONCompletedChatTurn`` for any ``JSONStreamGenerable`` output type.
  ///
  /// The final output may fail to parse when the model emits function calls instead of final
  /// content, or when the final response does not contain valid JSON matching the target schema.
  ///
  /// During streaming, partial values are best-effort and may be `nil` when no parseable JSON
  /// fragment is available for a token.
  ///
  /// ```swift
  /// @StreamParseable
  /// @JSONSchema
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// extension Recipe.Partial: Encodable {}
  ///
  /// let completion = try await actor.jsonStreamableComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self
  /// ) { _, _, partial in
  ///   // If nil, the model may be thinking, generating a function call, or misbehaving.
  ///   if let partial {
  ///     print("\nPartial: \(partial)")
  ///   }
  /// }
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: JSONStreamGenerable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, Output.Partial?) -> Void = { _, _ in }
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output>
  where Output.Partial: Sendable {
    try self.model.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a streamable ``CactusLanguageModel/JSONCompletedChatTurn`` for any ``JSONStreamGenerable`` output type.
  ///
  /// The final output may fail to parse when the model emits function calls instead of final
  /// content, or when the final response does not contain valid JSON matching the target schema.
  ///
  /// During streaming, partial values are best-effort and may be `nil` when no parseable JSON
  /// fragment is available for a token.
  ///
  /// ```swift
  /// @StreamParseable
  /// @JSONSchema
  /// struct Recipe: Codable {
  ///   var title: String
  ///   var servings: Int
  /// }
  ///
  /// extension Recipe.Partial: Encodable {}
  ///
  /// let completion = try await actor.jsonStreamableComplete(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self
  /// ) { _, _, partial in
  ///   // If nil, the model may be thinking, generating a function call, or misbehaving.
  ///   if let partial {
  ///     print("\nPartial: \(partial)")
  ///   }
  /// }
  /// print(try completion.output.get())
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``CactusLanguageModel/ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``CactusLanguageModel/JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``CactusLanguageModel/FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: JSONStreamGenerable>(
    messages: [CactusLanguageModel.ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: CactusLanguageModel.JSONChatCompletionOptions =
      CactusLanguageModel.JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [CactusLanguageModel.FunctionDefinition] = [],
    onToken: @escaping @Sendable (String, UInt32, Output.Partial?) -> Void
  ) async throws -> CactusLanguageModel.JSONCompletedChatTurn<Output> {
    try self.model.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }
}

// MARK: - Transcribe

extension CactusLanguageModelActor {
  /// Transcribes the specified audio buffer.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer to transcribe.
  ///   - prompt: The prompt to use for transcription.
  ///   - options: The ``CactusLanguageModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusLanguageModel.Transcription.Options? = nil,
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusLanguageModel.Transcription {
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
  ///   - options: The ``CactusLanguageModel/Transcription/Options``.
  ///   - transcriptionMaxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/Transcription``.
  public func transcribe(
    buffer: [UInt8],
    prompt: String,
    options: CactusLanguageModel.Transcription.Options? = nil,
    transcriptionMaxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusLanguageModel.Transcription {
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
  ///   - options: The ``CactusLanguageModel/Transcription/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/Transcription``.
  public func transcribe(
    audio: URL,
    prompt: String,
    options: CactusLanguageModel.Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> CactusLanguageModel.Transcription {
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
  ///   - options: The ``CactusLanguageModel/Transcription/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/Transcription``.
  public func transcribe(
    audio: URL,
    prompt: String,
    options: CactusLanguageModel.Transcription.Options? = nil,
    maxBufferSize: Int? = nil,
    onToken: @escaping @Sendable (String, UInt32) -> Void
  ) async throws -> CactusLanguageModel.Transcription {
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

extension CactusLanguageModelActor {
  /// Runs voice activity detection on an audio file.
  ///
  /// - Parameters:
  ///   - audio: The audio file to analyze.
  ///   - options: The ``CactusLanguageModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusLanguageModel/VADResult``.
  public func vad(
    audio: URL,
    options: CactusLanguageModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusLanguageModel.VADResult {
    try self.model.vad(audio: audio, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``CactusLanguageModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusLanguageModel/VADResult``.
  public func vad(
    pcmBuffer: [UInt8],
    options: CactusLanguageModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusLanguageModel.VADResult {
    try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
  }

  /// Runs voice activity detection on a PCM byte buffer.
  ///
  /// - Parameters:
  ///   - pcmBuffer: The PCM byte buffer to analyze.
  ///   - options: The ``CactusLanguageModel/VADOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the result.
  /// - Returns: A ``CactusLanguageModel/VADResult``.
  public func vad(
    pcmBuffer: sending UnsafeBufferPointer<UInt8>,
    options: CactusLanguageModel.VADOptions? = nil,
    maxBufferSize: Int? = nil
  ) async throws -> CactusLanguageModel.VADResult {
    try self.model.vad(pcmBuffer: pcmBuffer, options: options, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Stop

extension CactusLanguageModelActor {
  /// Stops generation of an active chat completion.
  ///
  /// This method is safe to call from other threads.
  public func stop() async {
    self.model.stop()
  }
}

// MARK: - Reset

extension CactusLanguageModelActor {
  /// Resets the context state of the model.
  public func reset() async {
    self.model.reset()
  }
}

// MARK: - RAG Query

extension CactusLanguageModelActor {
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
  /// - Returns: A ``CactusLanguageModel/RAGQueryResult`` containing relevant document chunks.
  public func ragQuery(
    query: String,
    topK: Int = 10,
    maxBufferSize: Int? = nil
  ) async throws -> CactusLanguageModel.RAGQueryResult {
    try self.model.ragQuery(query: query, topK: topK, maxBufferSize: maxBufferSize)
  }
}

// MARK: - Exclusive Access

extension CactusLanguageModelActor {
  /// Provides exclusive access to the underlying language model.
  ///
  /// This method allows direct synchronous and exclusive access to the ``CactusLanguageModel``. The
  ///
  /// ```swift
  /// let result = try await actor.withLanguageModelAccess { model in
  ///   // ...
  /// }
  /// ```
  ///
  /// - Parameter operation: An operation to run with the model.
  /// - Returns: The operation return value.
  public func withLanguageModelAccess<T: Sendable, E: Error>(
    _ operation: @Sendable (CactusLanguageModel) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try operation(self.model)
  }
}
