extension CactusAgent {
  public func environment<Value>(
    _ path: WritableKeyPath<CactusEnvironmentValues, Value>,
    _ newValue: Value
  ) -> _TransformEnvironmentAgent<Self> {
    self.transformEnvironment(path) { $0 = newValue }
  }

  public func transformEnvironment<Value>(
    _ path: WritableKeyPath<CactusEnvironmentValues, Value>,
    _ transform: @escaping (inout Value) -> Void
  ) -> _TransformEnvironmentAgent<Self> {
    _TransformEnvironmentAgent(base: self) { transform(&$0[keyPath: path]) }
  }
}

public struct _TransformEnvironmentAgent<Base: CactusAgent>: CactusAgent {
  let base: Base
  let transform: (inout CactusEnvironmentValues) -> Void

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    var request = request
    transform(&request.environment)
    return try await self.base.stream(request: request, into: continuation)
  }
}
