// MARK: - CactusFunction

public protocol CactusFunction<Input, Output>: Sendable {
  associatedtype Input: ConvertibleFromJSONValue
  associatedtype Output: CactusPromptRepresentable

  var name: String { get }
  var description: String { get }
  var parametersSchema: JSONSchema { get }

  func invoke(input: Input, in environment: CactusEnvironmentValues) async throws -> Output
}

extension CactusFunction {
  public var name: String {
    typeName(Self.self)
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

// MARK: - Function Agent

extension CactusAgent {
  public func function(_ function: any CactusFunction) -> _TransformEnvironmentAgent<Self> {
    self.functions([function])
  }

  public func functions(_ functions: [any CactusFunction]) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.functions, functions)
  }

  public func appendingFunction(
    _ function: any CactusFunction
  ) -> _TransformEnvironmentAgent<Self> {
    self.appendingFunctions(CollectionOfOne(function))
  }

  public func appendingFunctions(
    _ functions: some Sequence<any CactusFunction>
  ) -> _TransformEnvironmentAgent<Self> {
    self.transformEnvironment(\.functions) { $0.append(contentsOf: functions) }
  }
}

// MARK: - Environment Value

extension CactusEnvironmentValues {
  public var functions: [any CactusFunction] {
    get { self[FunctionsKey.self] }
    set { self[FunctionsKey.self] = newValue }
  }

  private enum FunctionsKey: Key {
    static var defaultValue: [any CactusFunction] {
      []
    }
  }
}
