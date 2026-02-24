import Foundation
import StreamParsingCore

// MARK: - Stream Complete

extension CactusLanguageModel {
  /// Generates a completed chat turn with parser-driven partial updates.
  ///
  /// ```swift
  /// let parser = CactusLanguageModel.StreamParsingTokenParser(
  ///   streamParser: JSONStreamParser<MyPartial>(configuration: .init())
  /// )
  ///
  /// let completed = try model.streamComplete(
  ///   messages: [.user("Return JSON")],
  ///   parser: parser
  /// ) { _, partial in
  ///   print(partial)
  /// }
  /// print(completed.completion.response)
  /// ```
  ///
  /// - Parameters:
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - parser: The parser used to incrementally derive partial values from generated tokens.
  ///   - options: The ``ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func streamComplete<Parser: TokenParser>(
    messages: [ChatMessage],
    parser: Parser,
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, Parser.Partial?) -> Void = { _, _ in }
  ) throws -> CompletedChatTurn {
    try self.streamComplete(
      messages: messages,
      parser: parser,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _, partial in
      onToken(token, partial)
    }
  }

  /// Generates a completed chat turn with parser-driven partial updates.
  ///
  /// ```swift
  /// let parser = CactusLanguageModel.StreamParsingTokenParser(
  ///   streamParser: JSONStreamParser<MyPartial>(configuration: .init())
  /// )
  ///
  /// let completed = try model.streamComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - parser: The parser used to incrementally derive partial values from generated tokens.
  ///   - options: The ``ChatCompletion/Options``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Throws: Any parser error thrown while processing generated tokens.
  /// - Returns: A ``CactusLanguageModel/CompletedChatTurn``.
  public func streamComplete<Parser: TokenParser>(
    messages: [ChatMessage],
    parser: Parser,
    options: ChatCompletion.Options? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32, Parser.Partial?) -> Void
  ) throws -> CompletedChatTurn {
    var parser = parser
    var parserError: (any Error)?
    let completedTurn = try self.complete(
      messages: messages,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, tokenID in
      do {
        let partial = try parser.parse(token: token, tokenId: tokenID, model: self)
        onToken(token, tokenID, partial)
      } catch {
        parserError = error
        self.stop()
      }
    }
    if let parserError {
      throw parserError
    }
    return completedTurn
  }
}

// MARK: - JSON Completed Chat Turn

extension CactusLanguageModel {
  /// A completed JSON chat turn that includes typed output.
  ///
  /// The ``output`` contains the parsed value when generation produced valid JSON matching
  /// the target schema. If generation was interrupted, invalid, or resulted in function calls,
  /// the ``output`` is a failure.
  public struct JSONCompletedChatTurn<Output: Decodable> {
    /// The parsed JSON output result.
    public let output: Result<Output, any Error>

    /// The raw chat completion returned by the model.
    public let completion: ChatCompletion

    /// Canonical conversation messages that include the generated assistant turn.
    public let messages: [ChatMessage]
  }

  /// Options for generating a ``JSONCompletedChatTurn``.
  public struct JSONChatCompletionOptions: Sendable {
    /// Defines how the JSON schema is included in the prompt.
    public enum SchemaPromptMode: Sendable {
      /// Default behavior - includes the JSON schema in the prompt to bias the model.
      case `default`

      /// Excludes the JSON schema from the prompt entirely.
      ///
      /// Use this if your model is fine-tuned to respond in the correct format, or if the schema
      /// is included in an earlier part of the message history.
      case exclude

      /// Custom prompt builder that receives the original prompt content and JSON schema.
      case custom(@Sendable (String, JSONSchema) throws -> String)
    }

    /// The base ``ChatCompletion/Options`` used for inference.
    public var chatCompletionOptions: ChatCompletion.Options?

    /// The validator used when constructing ``Output`` from a JSON value.
    public var validator: JSONSchema.Validator

    /// The decoder used when constructing ``Output`` from a JSON value.
    public var decoder: JSONSchema.Value.Decoder

    /// The mode for including the JSON schema in the prompt.
    public var schemaPromptMode: SchemaPromptMode

    /// Creates options for generating a ``JSONCompletedChatTurn``.
    ///
    /// - Parameters:
    ///   - chatCompletionOptions: The base ``ChatCompletion/Options`` used for inference.
    ///   - validator: The validator used when constructing ``Output`` from a JSON value.
    ///   - decoder: The decoder used when constructing ``Output`` from a JSON value.
    ///   - schemaPromptMode: The mode for including the JSON schema in the prompt.
    public init(
      chatCompletionOptions: ChatCompletion.Options? = nil,
      validator: JSONSchema.Validator = .shared,
      decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
      schemaPromptMode: SchemaPromptMode = .default
    ) {
      self.chatCompletionOptions = chatCompletionOptions
      self.validator = validator
      self.decoder = decoder
      self.schemaPromptMode = schemaPromptMode
    }
  }

  /// An error thrown when resolving typed JSON output from a completion.
  public enum JSONOutputError: Error, Sendable {
    /// The model returned function calls instead of a final JSON payload.
    case functionCallReturned([FunctionCall])

    /// The model response contained no JSON payload after filtering.
    case missingJSONPayload
  }

  /// Generates a ``JSONCompletedChatTurn`` with a required schema parameter.
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
  /// let completion = try model.jsonComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonComplete<Output: Decodable>(
    messages: [ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _ in
      onToken(token)
    }
  }

  /// Generates a ``JSONCompletedChatTurn`` with a required schema parameter.
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
  /// let completion = try model.jsonComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonComplete<Output: Decodable>(
    messages: [ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> JSONCompletedChatTurn<Output> {
    var accumulator = NonThinkingTokenAccumulator()
    let completedTurn = try self.complete(
      messages: self.messagesWithJSONSchemaPrompt(
        messages: messages,
        jsonSchema: schema,
        schemaPromptMode: options.schemaPromptMode
      ),
      options: options.chatCompletionOptions,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: { token, tokenID in
        accumulator.append(token)
        onToken(token, tokenID)
      }
    )
    return JSONCompletedChatTurn(
      output: Result {
        try self.resolveJSONOutput(
          from: completedTurn.completion,
          filteredResponse: accumulator.response,
          jsonSchema: schema,
          validator: options.validator,
          decoder: options.decoder
        )
      },
      completion: completedTurn.completion,
      messages: completedTurn.messages
    )
  }

  /// Generates a streamable ``JSONCompletedChatTurn`` with a required schema parameter.
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
  /// let completion = try model.jsonStreamableComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: Decodable & StreamParseable>(
    messages: [ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, Output.Partial?) -> Void = { _, _ in }
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      schema: schema,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _, partial in
      onToken(token, partial)
    }
  }

  /// Generates a streamable ``JSONCompletedChatTurn`` with a required schema parameter.
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
  /// let completion = try model.jsonStreamableComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - schema: The JSON schema to validate against and inject into the user prompt.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: Decodable & StreamParseable>(
    messages: [ChatMessage],
    as outputType: Output.Type,
    schema: JSONSchema,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32, Output.Partial?) -> Void
  ) throws -> JSONCompletedChatTurn<Output> {
    var accumulator = NonThinkingTokenAccumulator()
    let parser = StreamParsingTokenParser(
      streamParser: JSONStreamParser<Output.Partial>(configuration: configuration)
    )

    let completedTurn = try self.streamComplete(
      messages: self.messagesWithJSONSchemaPrompt(
        messages: messages,
        jsonSchema: schema,
        schemaPromptMode: options.schemaPromptMode
      ),
      parser: parser,
      options: options.chatCompletionOptions,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, tokenID, partial in
      _ = accumulator.append(token)
      onToken(token, tokenID, partial)
    }

    return JSONCompletedChatTurn(
      output: Result {
        try self.resolveJSONOutput(
          from: completedTurn.completion,
          filteredResponse: accumulator.response,
          jsonSchema: schema,
          validator: options.validator,
          decoder: options.decoder
        )
      },
      completion: completedTurn.completion,
      messages: completedTurn.messages
    )
  }

  // MARK: - JSONGenerable JSON Complete

  /// Generates a ``JSONCompletedChatTurn`` for any ``JSONGenerable`` output type.
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
  /// let completion = try model.jsonComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonComplete<Output: JSONGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonComplete(
      messages: messages,
      as: outputType,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _ in
      onToken(token)
    }
  }

  /// Generates a ``JSONCompletedChatTurn`` for any ``JSONGenerable`` output type.
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
  /// let completion = try model.jsonComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonComplete<Output: JSONGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonComplete(
      messages: messages,
      as: outputType,
      schema: Output.jsonSchema,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }

  /// Generates a streamable ``JSONCompletedChatTurn`` for any ``JSONStreamGenerable`` output type.
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
  /// let completion = try model.jsonStreamableComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: JSONStreamGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, Output.Partial?) -> Void = { _, _ in }
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _, partial in
      onToken(token, partial)
    }
  }

  /// Generates a streamable ``JSONCompletedChatTurn`` for any ``JSONStreamGenerable`` output type.
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
  /// let completion = try model.jsonStreamableComplete(
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
  ///   - messages: The list of ``ChatMessage`` instances.
  ///   - as: The output type to decode from the JSON payload.
  ///   - configuration: The ``JSONStreamParserConfiguration``.
  ///   - options: The ``JSONChatCompletionOptions``.
  ///   - maxBufferSize: The maximum buffer size to store the completion.
  ///   - functions: A list of ``FunctionDefinition`` instances.
  ///   - onToken: A callback invoked whenever a token is generated.
  /// - Returns: A ``JSONCompletedChatTurn``.
  public func jsonStreamableComplete<Output: JSONStreamGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions = JSONChatCompletionOptions(),
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32, Output.Partial?) -> Void
  ) throws -> JSONCompletedChatTurn<Output> {
    try self.jsonStreamableComplete(
      messages: messages,
      as: outputType,
      schema: Output.jsonSchema,
      configuration: configuration,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: onToken
    )
  }
}

extension CactusLanguageModel.JSONCompletedChatTurn: Sendable where Output: Sendable {}

extension CactusLanguageModel {
  private func messagesWithJSONSchemaPrompt(
    messages: [ChatMessage],
    jsonSchema: JSONSchema,
    schemaPromptMode: JSONChatCompletionOptions.SchemaPromptMode = .default
  ) throws -> [ChatMessage] {
    switch schemaPromptMode {
    case .default:
      let prompt = try self.jsonSchemaPrompt(for: jsonSchema)
      return self.appendPromptToLastUserMessage(prompt: prompt, messages: messages)

    case .exclude:
      return messages

    case .custom(let builder):
      let originalPrompt = self.lastUserMessageContent(messages: messages)
      let prompt = try builder(originalPrompt, jsonSchema)
      return self.appendPromptToLastUserMessage(prompt: prompt, messages: messages)
    }
  }

  private func lastUserMessageContent(messages: [ChatMessage]) -> String {
    if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
      return messages[lastUserIndex].content
    }
    return ""
  }

  private func appendPromptToLastUserMessage(
    prompt: String,
    messages: [ChatMessage]
  ) -> [ChatMessage] {
    if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
      var messages = messages
      messages[lastUserIndex].content += "\n\n\(prompt)"
      return messages
    }

    var messages = messages
    messages.append(.user(prompt))
    return messages
  }

  private func jsonSchemaPrompt(for jsonSchema: JSONSchema) throws -> String {
    let schema = try String(decoding: ffiEncoder.encode(jsonSchema), as: UTF8.self)
    return """
      Return only valid JSON that matches this JSON Schema exactly.
      Do not include markdown code fences, prose, or additional keys.
      JSON Schema:
      \(schema)
      """
  }

  private func resolveJSONOutput<Output: Decodable>(
    from completion: ChatCompletion,
    filteredResponse: String,
    jsonSchema: JSONSchema,
    validator: JSONSchema.Validator,
    decoder: JSONSchema.Value.Decoder
  ) throws -> Output {
    guard completion.functionCalls.isEmpty else {
      throw JSONOutputError.functionCallReturned(completion.functionCalls)
    }

    let jsonText = filteredResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !jsonText.isEmpty else { throw JSONOutputError.missingJSONPayload }
    let value = try ffiDecoder.decode(JSONSchema.Value.self, from: Data(jsonText.utf8))
    try validator.validate(value: value, with: jsonSchema)
    return try decoder.decode(Output.self, from: value)
  }
}
