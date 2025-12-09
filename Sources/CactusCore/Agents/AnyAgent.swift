public struct AnyAgent<Input, Output: ConvertibleFromCactusResponse>: CactusAgent {
  private let base: any CactusAgent<Input, Output>

  public init(_ base: any CactusAgent<Input, Output>) {
    self.base = base
  }

  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(label: "AnyAgent")
    )
    guard let node else { return unableToAddGraphNode() }
    self.base.build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
    try await self.base.stream(request: request, into: continuation)
  }
}
