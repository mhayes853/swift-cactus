public struct EmptyAgent<Input, Output>: CactusAgent {
  @inlinable
  public init() {}

  @inlinable
  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "EmptyAgent"))
  }

  @inlinable
  @inline(__always)
  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
