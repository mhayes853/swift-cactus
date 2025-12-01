public protocol CactusFunction<Input, Output> {
  associatedtype Input: ConvertibleFromJSONValue
  associatedtype Output: CactusPromptRepresentable

  var name: String { get }
  var description: String { get }
  var parametersSchema: JSONSchema { get }
  var includesSchemaInSystemPrompt: Bool { get }

  func invoke(input: Input) async throws -> Output
}

extension CactusFunction {
  public var name: String {
    typeName(Self.self)
  }

  public var includesSchemaInSystemPrompt: Bool {
    false
  }
}

extension CactusFunction where Input: JSONValue.Generable {
  public var parametersSchema: JSONSchema {
    Input.jsonSchema
  }
}

extension CactusFunction {
  public var definition: CactusLanguageModel.FunctionDefinition {
    CactusLanguageModel.FunctionDefinition(
      name: self.name,
      description: self.description,
      parameters: self.parametersSchema
    )
  }
}
