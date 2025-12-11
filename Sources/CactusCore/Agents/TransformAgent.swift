// MARK: - TransformInput

extension CactusAgent {
  public func input<Input>(_ input: Self.Input) -> _TransformInputAgent<Self, Input> {
    self.transformInput { _ in input }
  }

  public func transformInput<Input>(
    _ transform: @escaping (Input) throws -> Self.Input
  ) -> _TransformInputAgent<Self, Input> {
    _TransformInputAgent(base: self, transform: transform)
  }
}

public struct _TransformInputAgent<Base: CactusAgent, Input>: CactusAgent {
  let base: Base
  let transform: (Input) throws -> Base.Input

  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "_TransformInputAgent (\(typeName(Base.Input.self)) -> \(typeName(Input.self)))"
      )
    )
    guard let node else { return unableToAddGraphNode() }
    self.base._build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    fatalError()
  }
}

// MARK: - TransformOutput

extension CactusAgent {
  public func inputAsOutput() -> _TransformOutputAgent<Self, Input> where Input: Sendable {
    self.transformOutput { $1 }
  }

  public func transformOutput<Output>(
    _ transform: @escaping (Self.Output) throws -> Output
  ) -> _TransformOutputAgent<Self, Output> {
    self.transformOutput { output, _ in try transform(output) }
  }

  public func transformOutput<Output>(
    _ transform: @escaping (Self.Output, Input) throws -> Output
  ) -> _TransformOutputAgent<Self, Output> {
    _TransformOutputAgent(base: self, transform: transform)
  }
}

public struct _TransformOutputAgent<Base: CactusAgent, Output: Sendable>: CactusAgent {
  let base: Base
  let transform: (Base.Output, Base.Input) throws -> Output

  public func _build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "_TransformOutputAgent (\(typeName(Base.Output.self)) -> \(typeName(Output.self)))"
      )
    )
    guard let node else { return unableToAddGraphNode() }
    self.base._build(graph: &graph, at: node.id, in: environment)
  }

  public nonisolated(nonsending) func _stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    fatalError()
  }
}
