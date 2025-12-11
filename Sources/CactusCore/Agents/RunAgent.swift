public struct Run<Input: Sendable, Output: Sendable>: CactusAgent {
  @usableFromInline
  let action: (Input) async throws -> Output

  @inlinable
  public init(_ action: @escaping (Input) async throws -> Output) {
    self.action = action
  }

  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(to: nodeId, fields: CactusAgentGraph.Node.Fields(label: "Run"))
  }

  @inlinable
  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    let output = try await self.action(request.input)
    return .finalOutput(output)
  }
}
