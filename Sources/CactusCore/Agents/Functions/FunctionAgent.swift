// MARK: - Function Agent

extension CactusAgent {
  public func function(_ function: any CactusFunction) -> _TransformEnvironmentAgent<Self> {
    self.functions([function])

  }

  public func functions(_ functions: [any CactusFunction]) -> _TransformEnvironmentAgent<Self> {
    self.transformEnvironment { $0.functions.append(contentsOf: functions) }
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
