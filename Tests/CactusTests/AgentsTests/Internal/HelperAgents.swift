import Cactus

// MARK: - NeverAgent

struct NeverAgent: CactusAgent {
  func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "NeverAgent"))
  }

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<String>,
    into continuation: CactusAgentStream<String>.Continuation
  ) async throws {
    try await Task.never()
  }
}

// MARK: - PassthroughAgent

struct PassthroughAgent: CactusAgent {
  func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "PassthroughAgent"))
  }

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<String>,
    into continuation: CactusAgentStream<String>.Continuation
  ) async throws {
  }
}
