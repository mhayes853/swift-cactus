// MARK: - CactusFunction

/// A strongly typed function that can be exposed to a language model.
public protocol CactusFunction<Input, Output>: Sendable {
  associatedtype Input: Decodable & Sendable
  associatedtype Output: CactusPromptRepresentable

  /// The unique function name exposed to the model.
  var name: String { get }

  /// A short description of what the function does.
  var description: String { get }

  /// The JSON schema describing accepted input parameters.
  var parametersSchema: JSONSchema { get }

  /// Invokes the function with decoded model input.
  func invoke(input: sending Input) async throws -> sending Output
}

// MARK: - Defaults

extension CactusFunction where Input: JSONSchemaRepresentable {
  /// The default parameter schema derived from ``Input/jsonSchema``.
  ///
  /// This is used to validate raw model-emitted arguments before decoding.
  public var parametersSchema: JSONSchema {
    Input.jsonSchema
  }
}

extension CactusFunction {
  /// A language model function definition derived from this function.
  public var definition: CactusModel.FunctionDefinition {
    CactusModel.FunctionDefinition(
      name: self.name,
      description: self.description,
      parameters: self.parametersSchema
    )
  }

  /// Invokes this function from raw function-call arguments.
  ///
  /// The arguments are validated against ``parametersSchema`` and then decoded into `Input`
  /// before calling ``invoke(input:)``.
  ///
  /// - Parameters:
  ///   - rawArguments: The args returned from a model function call.
  ///   - decoder: The ``JSONSchema/Value/Decoder`` to use.
  ///   - validator: The ``JSONSchema/Validator`` to use.
  /// - Returns: The invoked function output converted to ``CactusPromptContent``.
  public func invoke(
    rawArguments: [String: JSONSchema.Value],
    decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
    validator: JSONSchema.Validator = .shared
  ) async throws -> CactusPromptContent {
    try validator.validate(value: .object(rawArguments), with: self.parametersSchema)
    let input = try decoder.decode(Input.self, from: .object(rawArguments))
    let output = try await self.invoke(input: input)
    return try output.promptContent
  }
}
