import Cactus

// MARK: - NeverAgent

struct NeverAgent: CactusAgent {
  func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "NeverAgent"))
  }

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<String>,
    into continuation: CactusAgentStream<String>.Continuation
  ) async throws -> CactusAgentStream<String>.Response {
    try await Task.never()
    return .finalOutput("")
  }
}

// MARK: - PassthroughAgent

struct PassthroughAgent: CactusAgent {
  func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "PassthroughAgent"))
  }

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<String>,
    into continuation: CactusAgentStream<String>.Continuation
  ) async throws -> CactusAgentStream<String>.Response {
    .finalOutput(request.input)
  }
}
