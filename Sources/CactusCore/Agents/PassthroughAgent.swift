public struct Passthrough<Input: Sendable, Child: CactusAgent>: CactusAgent
where Child.Input == Input {
  private let child: Child

  public init(@CactusAgentBuilder<Child.Input, Child.Output> child: () -> Child) {
    self.child = child()
  }

  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(label: "PassthroughAgent")
    )
    guard let node else { return unableToAddGraphNode() }
    self.child._build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Input>.Continuation
  ) async throws -> CactusAgentStream<Input>.Response {
    .finalOutput(request.input)
  }
}
