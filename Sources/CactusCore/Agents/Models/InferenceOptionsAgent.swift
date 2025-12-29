extension CactusAgent {
  public func inferenceOptions(
    _ options: CactusLanguageModel.InferenceOptions?
  ) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.inferenceOptions, options)
  }
}

extension CactusEnvironmentValues {
  public var inferenceOptions: CactusLanguageModel.InferenceOptions? {
    get { self[InferenceOptionsKey.self] }
    set { self[InferenceOptionsKey.self] = newValue }
  }

  private enum InferenceOptionsKey: Key {
    static let defaultValue: CactusLanguageModel.InferenceOptions? = nil
  }
}
