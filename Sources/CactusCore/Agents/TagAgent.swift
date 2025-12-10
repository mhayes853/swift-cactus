extension CactusAgent {
  public func tag<Tag>(_ tag: Tag) -> _TagAgent<Self, Tag> {
    _TagAgent(base: self, tag: tag)
  }
}

public struct _TagAgent<Base: CactusAgent, Tag: Hashable & Sendable>: CactusAgent {
  let base: Base
  let tag: Tag

  private var tagDescription: String {
    if self.tag is any StringProtocol {
      "\"\(self.tag)\""
    } else {
      "\(self.tag)"
    }
  }

  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "_TagAgent (\(self.tagDescription))",
        tag: self.tag
      )
    )
    guard let node else { return unableToAddGraphNode() }
    self.base.build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    try await self.base.stream(request: request, into: continuation)
  }
}
