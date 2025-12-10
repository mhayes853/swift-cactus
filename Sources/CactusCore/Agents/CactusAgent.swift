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

// MARK: - CactusAgentResponse

public struct CactusAgentResponse<Output: Sendable>: Sendable {
  public enum Action: Sendable {
    case returnOutputValue(Output)
    case collectTokensIntoOutput
  }

  public let action: Action
  public let metrics: CactusAgentInferenceMetrics

  public static func finalOutput(
    _ value: Output,
    metrics: CactusAgentInferenceMetrics = CactusAgentInferenceMetrics()
  ) -> Self {
    Self(action: .returnOutputValue(value), metrics: metrics)
  }
}

extension CactusAgentResponse where Output: ConvertibleFromCactusResponse {
  public static func collectTokensIntoOutput(
    metrics: CactusAgentInferenceMetrics = CactusAgentInferenceMetrics()
  ) -> Self {
    Self(action: .collectTokensIntoOutput, metrics: metrics)
  }
}

// MARK: - CactusAgent

public protocol CactusAgent<Input, Output> {
  associatedtype Input
  associatedtype Output: Sendable

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
  ) async throws -> CactusAgentResponse<Output>
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
  ) async throws -> CactusAgentResponse<Output> {
    try await self.body(environment: request.environment)
      .stream(request: request, into: continuation)
  }
}
