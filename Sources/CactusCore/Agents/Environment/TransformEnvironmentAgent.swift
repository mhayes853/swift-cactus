extension CactusAgent {
  public func environment<Value: Sendable>(
    _ path: WritableKeyPath<CactusEnvironmentValues, Value> & Sendable,
    _ newValue: Value
  ) -> _TransformEnvironmentAgent<Self> {
    self.transformEnvironment(path) { $0 = newValue }
  }

  public func transformEnvironment<Value: Sendable>(
    _ path: WritableKeyPath<CactusEnvironmentValues, Value> & Sendable,
    _ transform: @escaping @Sendable (inout Value) -> Void
  ) -> _TransformEnvironmentAgent<Self> {
    _TransformEnvironmentAgent(base: self) { transform(&$0[keyPath: path]) }
  }
}

public struct _TransformEnvironmentAgent<Base: CactusAgent>: CactusAgent {
  @usableFromInline
  let base: Base

  @usableFromInline
  let transform: @Sendable (inout CactusEnvironmentValues) -> Void

  @inlinable
  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    var request = request
    transform(&request.environment)
    return try await self.base.primitiveStream(request: request, into: continuation)
  }
}
