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

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws {
    try await self.base.stream(request: request, into: continuation)
  }
}
