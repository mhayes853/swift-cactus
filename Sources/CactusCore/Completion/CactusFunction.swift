// MARK: - CactusFunction

/// A strongly typed function that can be exposed to a language model.
public protocol CactusFunction<Input, Output>: Sendable {
  associatedtype Input: Decodable
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
  public var parametersSchema: JSONSchema {
    Input.jsonSchema
  }
}

extension CactusFunction {
  /// A language model function definition derived from this function.
  public var definition: CactusLanguageModel.FunctionDefinition {
    CactusLanguageModel.FunctionDefinition(
      name: self.name,
      description: self.description,
      parameters: self.parametersSchema
    )
  }
}
