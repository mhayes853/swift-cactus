import Foundation
import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<Input, Output: Sendable>: Sendable, Identifiable {
  public typealias Response = CactusAgentResponse<Output>

  private let agentActor: AgentActor
  private let observationRegistrar = _ObservationRegistrar()
  private let _responseStream = Lock<CactusAgentStream<Output>?>(nil)

  public let id = UUID()

  public var isResponding: Bool {
    self.observationRegistrar.access(self, keyPath: \.isResponding)
    return self._responseStream.withLock { $0 != nil }
  }

  public init(_ agent: sending some CactusAgent<Input, Output>) {
    self.agentActor = AgentActor(agent)
  }

  public func graph(
    for environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async -> CactusAgentGraph {
    var environment = environment
    environment.sessionId = self.id
    return await self.agentActor.graph(for: environment)
  }

  public func stream(
    for message: sending Input,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async -> CactusAgentStream<Output> {
    var environment = environment
    environment.sessionId = self.id

    let graph = await self.agentActor.graph(for: environment)
    let request = UnsafeTransfer(
      value: CactusAgentRequest(input: message, environment: environment)
    )

    return self.withResponseTask {
      let stream = CactusAgentStream<Output>(graph: graph) { continuation in
        let response = try await self.agentActor.stream(request: request.value, into: continuation)
        self.withResponseTask { $0 = nil }
        return response
      }
      $0 = stream
      return stream
    }
  }

  public func respond(to message: sending Input) async throws -> Response {
    let stream = await self.stream(for: message)
    return try await withTaskCancellationHandler {
      try await stream.collectFinalResponse()
    } onCancel: {
      stream.stop()
    }
  }

  private func withResponseTask<T>(work: (inout CactusAgentStream<Output>?) -> T) -> T {
    self.observationRegistrar.withMutation(of: self, keyPath: \.isResponding) {
      self._responseStream.withLock { work(&$0) }
    }
  }
}

// MARK: - Agent Actor

extension CactusAgenticSession {
  private final actor AgentActor {
    let agent: any CactusAgent<Input, Output>

    init(_ agent: sending some CactusAgent<Input, Output>) {
      self.agent = agent
    }

    func stream(
      request: CactusAgentRequest<Input>,
      into continuation: CactusAgentStream<Output>.Continuation
    ) async throws -> CactusAgentStream<Output>.Response {
      try await self.agent.stream(request: request, into: continuation)
    }

    func graph(for environment: CactusEnvironmentValues) -> CactusAgentGraph {
      var graph = CactusAgentGraph(
        root: CactusAgentGraph.Node.Fields(label: "CactusAgenticSessionGraphRoot")
      )
      self.agent.build(graph: &graph, at: graph.root.id, in: environment)
      return graph
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: _Observable {}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var sessionId: UUID? {
    get { self[SessionIdKey.self] }
    set { self[SessionIdKey.self] = newValue }
  }

  private enum SessionIdKey: Key {
    static let defaultValue: UUID? = nil
  }
}
