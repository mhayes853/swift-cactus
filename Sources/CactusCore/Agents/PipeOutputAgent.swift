extension CactusAgent {
  public func pipeOutput<PipedOutput, Piped: CactusAgent<Output, PipedOutput>>(
    to agent: Piped
  ) -> _PipeOutputAgent<Self, Piped> {
    _PipeOutputAgent(base: self, piped: agent)
  }

  public func pipeOutput<PipedOutput, Piped: CactusAgent<Output, PipedOutput>>(
    @CactusAgentBuilder<Output, PipedOutput> to agent: () -> Piped
  ) -> _PipeOutputAgent<Self, Piped> {
    _PipeOutputAgent(base: self, piped: agent())
  }
}

public struct _PipeOutputAgent<Base: CactusAgent, Piped: CactusAgent>: CactusAgent
where Base.Output == Piped.Input {
  let base: Base
  let piped: Piped

  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let nodeId = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "_PipeOutputAgent (\(typeName(Base.Output.self)))"
      )
    )
    guard let node = nodeId else { return unableToAddGraphNode() }
    self.base._build(graph: &graph, at: node.id, in: environment)
    self.piped._build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Piped.Output>.Continuation
  ) async throws -> CactusAgentStream<Piped.Output>.Response {
    fatalError()
  }
}
