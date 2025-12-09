import Foundation
import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<
  Input,
  Output: ConvertibleFromCactusResponse
>: Sendable, Identifiable {
  private let agentActor: AgentActor

  private let observationRegistrar = _ObservationRegistrar()

  public let id = UUID()

  private let _isResponding = Lock(false)
  public private(set) var isResponding: Bool {
    get {
      self.observationRegistrar.access(self, keyPath: \.isResponding)
      return self._isResponding.withLock { $0 }
    }
    set {
      self.observationRegistrar.withMutation(of: self, keyPath: \.isResponding) {
        self._isResponding.withLock { $0 = newValue }
      }
    }
  }

  public init(_ agent: sending some CactusAgent<Input, Output>) {
    self.agentActor = AgentActor(agent)
  }

  public func graph(
    for environment: sending CactusEnvironmentValues = CactusEnvironmentValues()
  ) async -> CactusAgentGraph {
    var environment = environment
    environment.sessionId = self.id
    return await self.agentActor.graph(for: environment)
  }

  public func stream(
    for message: Input,
    environment: sending CactusEnvironmentValues = CactusEnvironmentValues()
  ) async -> CactusAgentStream<Output> {
    CactusAgentStream(graph: await self.graph(for: environment))
  }

  public func respond(to message: Input) async throws -> Output {
    let stream = await self.stream(for: message)
    return try await withTaskCancellationHandler {
      try await stream.collectFinalResponse()
    } onCancel: {
      stream.stop()
    }
  }
}

// MARK: - Agent Actor

extension CactusAgenticSession {
  private final actor AgentActor {
    private let agent: any CactusAgent<Input, Output>

    init(_ agent: sending some CactusAgent<Input, Output>) {
      self.agent = agent
    }

    func graph(for environment: sending CactusEnvironmentValues) -> sending CactusAgentGraph {
      nonisolated(unsafe) var graph = CactusAgentGraph(
        root: CactusAgentGraph.Node.Fields(label: "CactusAgenticSessionGraphRoot")
      )
      self.agent.build(graph: &graph, at: graph.root.id, in: environment)
      return graph
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: _Observable {

}

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
