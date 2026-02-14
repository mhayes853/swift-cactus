import Foundation
import StreamParsingCore

// MARK: - JSONChatCompletion

extension CactusLanguageModel {
  /// A chat completion result that includes a typed JSON output.
  ///
  /// The ``output`` contains the parsed value when generation produced valid JSON matching
  /// ``Output/jsonSchema``. If generation was interrupted, invalid, or resulted in function calls,
  /// the ``output`` is a failure.
  public struct JSONChatCompletion<Output: JSONGenerable> {
    /// The parsed JSON output result.
    public let output: Result<Output, any Error>

    /// The raw chat completion returned by the model.
    public let completion: ChatCompletion
  }

  /// Options for generating a ``JSONChatCompletion``.
  public struct JSONChatCompletionOptions<Output: JSONGenerable>: Sendable {
    /// The base ``ChatCompletion/Options`` used for inference.
    public var chatCompletionOptions: ChatCompletion.Options?

    /// The validator used when constructing ``Output`` from a JSON value.
    public var validator: JSONSchema.Validator

    /// The decoder used when constructing ``Output`` from a JSON value.
    public var decoder: JSONSchema.Value.Decoder

    /// An optional callback for overriding the injected JSON system prompt.
    ///
    /// When `nil`, a default prompt containing ``Output/jsonSchema`` is used.
    public var jsonSystemPrompt: (@Sendable (Output.Type) throws -> String)?

    /// Creates options for generating a ``JSONChatCompletion``.
    ///
    /// - Parameters:
    ///   - chatCompletionOptions: The base ``ChatCompletion/Options`` used for inference.
    ///   - validator: The validator used when constructing ``Output`` from a JSON value.
    ///   - decoder: The decoder used when constructing ``Output`` from a JSON value.
    ///   - jsonSystemPrompt: An optional callback for overriding the injected JSON system prompt.
    public init(
      chatCompletionOptions: ChatCompletion.Options? = nil,
      validator: JSONSchema.Validator = .shared,
      decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
      jsonSystemPrompt: (@Sendable (Output.Type) throws -> String)? = nil
    ) {
      self.chatCompletionOptions = chatCompletionOptions
      self.validator = validator
      self.decoder = decoder
      self.jsonSystemPrompt = jsonSystemPrompt
    }
  }

  /// An error thrown when resolving typed JSON output from a chat completion.
  public enum JSONOutputError: Error, Sendable {
    /// The model returned function calls instead of a final JSON payload.
    case functionCallReturned([FunctionCall])

    /// The model response contained no JSON payload after filtering.
    case missingJSONPayload
  }

  /// Generates a ``JSONChatCompletion``.
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
  /// let completion = try model.jsonChatCompletion(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   options: CactusLanguageModel.JSONChatCompletionOptions(
  ///     chatCompletionOptions: .init(modelType: model.configurationFile.modelType ?? .qwen)
  ///   )
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
  /// - Returns: A ``JSONChatCompletion``.
  public func jsonChatCompletion<Output: JSONGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    options: JSONChatCompletionOptions<Output>? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String) -> Void = { _ in }
  ) throws -> JSONChatCompletion<Output> {
    try self.jsonChatCompletion(
      messages: messages,
      as: outputType,
      options: options,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, _ in
      onToken(token)
    }
  }

  /// Generates a ``JSONChatCompletion``.
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
  /// let completion = try model.jsonChatCompletion(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   options: CactusLanguageModel.JSONChatCompletionOptions(
  ///     chatCompletionOptions: .init(modelType: model.configurationFile.modelType ?? .qwen)
  ///   )
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
  /// - Returns: A ``JSONChatCompletion``.
  public func jsonChatCompletion<Output: JSONGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    options: JSONChatCompletionOptions<Output>? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32) -> Void
  ) throws -> JSONChatCompletion<Output> {
    let jsonOutputOptions = options ?? JSONChatCompletionOptions<Output>()
    var accumulator = NonThinkingTokenAccumulator()
    let completion = try self.chatCompletion(
      messages: try self.messagesWithJSONSchemaPrompt(
        messages: messages,
        output: outputType,
        jsonSystemPrompt: jsonOutputOptions.jsonSystemPrompt
      ),
      options: jsonOutputOptions.chatCompletionOptions,
      maxBufferSize: maxBufferSize,
      functions: functions,
      onToken: { token, tokenID in
        _ = accumulator.append(token)
        onToken(token, tokenID)
      }
    )
    return JSONChatCompletion(
      output: Result {
        try self.resolveJSONOutput(
          from: completion,
          filteredResponse: accumulator.response,
          validator: jsonOutputOptions.validator,
          decoder: jsonOutputOptions.decoder
        )
      },
      completion: completion
    )
  }

  /// Generates a streamable ``JSONChatCompletion`` with incremental partial output updates.
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
  /// let completion = try model.jsonStreamableChatCompletion(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   options: CactusLanguageModel.JSONChatCompletionOptions(
  ///     chatCompletionOptions: .init(modelType: model.configurationFile.modelType ?? .qwen)
  ///   )
  /// ) { _, _, partial in
  ///   // 🔵 If this is nil, then either the model is thinking, generating a function call, or misbehaving.
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
  /// - Returns: A ``JSONChatCompletion``.
  public func jsonStreamableChatCompletion<Output: JSONStreamGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions<Output>? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, Output.Partial?) -> Void = { _, _ in }
  ) throws -> JSONChatCompletion<Output> {
    try self.jsonStreamableChatCompletion(
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

  /// Generates a streamable ``JSONChatCompletion`` with incremental partial output updates.
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
  /// let completion = try model.jsonStreamableChatCompletion(
  ///   messages: [
  ///     .system("You are a helpful cooking assistant."),
  ///     .user("Create a recipe with a title and servings.")
  ///   ],
  ///   as: Recipe.self,
  ///   options: CactusLanguageModel.JSONChatCompletionOptions(
  ///     chatCompletionOptions: .init(modelType: model.configurationFile.modelType ?? .qwen)
  ///   )
  /// ) { _, _, partial in
  ///   // 🔵 If this is nil, then either the model is thinking, generating a function call, or misbehaving.
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
  /// - Returns: A ``JSONChatCompletion``.
  public func jsonStreamableChatCompletion<Output: JSONStreamGenerable>(
    messages: [ChatMessage],
    as outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration(),
    options: JSONChatCompletionOptions<Output>? = nil,
    maxBufferSize: Int? = nil,
    functions: [FunctionDefinition] = [],
    onToken: (String, UInt32, Output.Partial?) -> Void
  ) throws -> JSONChatCompletion<Output> {
    let jsonOutputOptions = options ?? JSONChatCompletionOptions<Output>()
    var accumulator = NonThinkingTokenAccumulator()
    var stream = PartialsStream<Output.Partial, JSONStreamParser<Output.Partial>>(
      from: .json(configuration: configuration)
    )
    var hasDetectedFunctionCall = false
    var hasParserFailed = false
    let functionCallStartTokenIDs: Set<UInt32> =
      switch self.configurationFile.modelType {
      case .qwen: [151657]
      case .lfm2: [10]
      case .gemma: [48]
      default: []
      }

    let completion = try self.chatCompletion(
      messages: try self.messagesWithJSONSchemaPrompt(
        messages: messages,
        output: outputType,
        jsonSystemPrompt: jsonOutputOptions.jsonSystemPrompt
      ),
      options: jsonOutputOptions.chatCompletionOptions,
      maxBufferSize: maxBufferSize,
      functions: functions
    ) { token, tokenID in
      let visibleToken = accumulator.append(token)

      if functionCallStartTokenIDs.contains(tokenID) {
        hasDetectedFunctionCall = true
      }

      if hasDetectedFunctionCall || hasParserFailed {
        onToken(token, tokenID, nil)
        return
      }

      guard let visibleToken else {
        onToken(token, tokenID, nil)
        return
      }

      do {
        let partial = try stream.next(visibleToken.utf8)
        onToken(token, tokenID, partial)
      } catch {
        hasParserFailed = true
        onToken(token, tokenID, nil)
      }
    }

    return JSONChatCompletion(
      output: Result {
        try self.resolveJSONOutput(
          from: completion,
          filteredResponse: accumulator.response,
          validator: jsonOutputOptions.validator,
          decoder: jsonOutputOptions.decoder
        )
      },
      completion: completion
    )
  }
}

extension CactusLanguageModel.JSONChatCompletion: Sendable where Output: Sendable {}

extension CactusLanguageModel {
  private func messagesWithJSONSchemaPrompt<Output: JSONGenerable>(
    messages: [ChatMessage],
    output: Output.Type,
    jsonSystemPrompt: (@Sendable (Output.Type) throws -> String)?
  ) throws -> [ChatMessage] {
    let prompt = try jsonSystemPrompt?(output) ?? self.jsonSchemaPrompt(for: output)
    if let firstSystemIndex = messages.firstIndex(where: { $0.role == .system }) {
      var messages = messages
      messages[firstSystemIndex].content += "\n\n\(prompt)"
      return messages
    }

    var messages = messages
    messages.insert(.system(prompt), at: 0)
    return messages
  }

  private func jsonSchemaPrompt<Output: JSONGenerable>(for output: Output.Type) throws -> String {
    let schema = try String(decoding: ffiEncoder.encode(Output.jsonSchema), as: UTF8.self)
    return """
      Return only valid JSON that matches this JSON Schema exactly.
      Do not include markdown code fences, prose, or additional keys.
      JSON Schema:
      \(schema)
      """
  }

  private func resolveJSONOutput<Output: JSONGenerable>(
    from completion: ChatCompletion,
    filteredResponse: String,
    validator: JSONSchema.Validator,
    decoder: JSONSchema.Value.Decoder
  ) throws -> Output {
    guard completion.functionCalls.isEmpty else {
      throw JSONOutputError.functionCallReturned(completion.functionCalls)
    }

    let jsonText = filteredResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !jsonText.isEmpty else { throw JSONOutputError.missingJSONPayload }
    let value = try ffiDecoder.decode(JSONSchema.Value.self, from: Data(jsonText.utf8))
    return try Output(jsonValue: value, validator: validator, decoder: decoder)
  }
}

// MARK: - NonThinkingTokenAccumulator

private struct NonThinkingTokenAccumulator {
  private var isInsideThinkTag = false
  private(set) var response = ""

  @discardableResult
  mutating func append(_ token: String) -> String? {
    switch token {
    case "<think>":
      self.isInsideThinkTag = true
      return nil
    case "</think>":
      self.isInsideThinkTag = false
      return nil
    default:
      guard !self.isInsideThinkTag else { return nil }
      self.response += token
      return token
    }
  }
}
