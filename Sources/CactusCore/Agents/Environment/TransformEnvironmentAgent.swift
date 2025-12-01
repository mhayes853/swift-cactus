extension CactusAgent {
  public func environment<Value>(
    _ path: WritableKeyPath<CactusEnvironmentValues, Value>,
    _ newValue: Value
  ) -> _TransformEnvironmentAgent<Self> {
    self.transformEnvironment { $0[keyPath: path] = newValue }
  }

  public func transformEnvironment(
    _ transform: @escaping (inout CactusEnvironmentValues) -> Void
  ) -> _TransformEnvironmentAgent<Self> {
    _TransformEnvironmentAgent(base: self, transform: transform)
  }
}

public struct _TransformEnvironmentAgent<Base: CactusAgent>: CactusAgent {
  let base: Base
  let transform: (inout CactusEnvironmentValues) -> Void

  public func body(input: Base.Input) -> some CactusAgent<Base.Input, Base.Output> {
    return self.base
  }
}
