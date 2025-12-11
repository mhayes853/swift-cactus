public struct Stream<Input: Sendable, Output: Sendable>: CactusAgent {
  @usableFromInline
  let stream:
    (
      CactusAgentRequest<Input>,
      CactusAgentStream<Output>.Continuation
    ) async throws -> CactusAgentStream<Output>.Response

  @inlinable
  public init(
    _ stream:
      @escaping (
        CactusAgentRequest<Input>,
        CactusAgentStream<Output>.Continuation
      ) async throws -> CactusAgentStream<Output>.Response
  ) {
    self.stream = stream
  }

  @inlinable
  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "Stream"))
  }

  @inlinable
  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    try await self.stream(request, continuation)
  }
}
