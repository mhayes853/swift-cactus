import Foundation

// MARK: - CactusAgentRequest

public struct CactusAgentRequest<Input> {
  public var input: Input
  public var environment: CactusEnvironmentValues

  public init(
    input: Input,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.input = input
    self.environment = environment
  }
}

// MARK: - CactusAgent

public protocol CactusAgent<Input, Output> {
  associatedtype Input
  associatedtype Output: ConvertibleFromCactusResponse

  associatedtype Body

  func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  )

  @CactusAgentBuilder<Input, Output>
  func body(environment: CactusEnvironmentValues) -> Body

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws
}

extension CactusAgent where Body == Never {
  @_transparent
  public func body(environment: CactusEnvironmentValues) -> Never {
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not invoke an agent's 'body' method directly, as it may not exist. To run an agent, \
      call 'CactusAgent.stream(request:into:)', instead.
      """
    )
  }
}

extension CactusAgent where Body: CactusAgent<Input, Output> {
  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    let node = graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(label: typeName(Self.self))
    )
    guard let node else { return unableToAddGraphNode() }
    self.body(environment: environment).build(graph: &graph, at: node.id, in: environment)
  }

  @inlinable
  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
    try await self.body(environment: request.environment)
      .stream(request: request, into: continuation)
  }
}
