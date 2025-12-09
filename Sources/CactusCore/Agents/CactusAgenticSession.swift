import Foundation
import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<Input, Output: Sendable>: Sendable, Identifiable {
  private let agentActor: AgentActor

  private let observationRegistrar = _ObservationRegistrar()

  public let id = UUID()

  private let _responseTask = Lock<Task<Void, any Error>?>(nil)
  public var isResponding: Bool {
    self.observationRegistrar.access(self, keyPath: \.isResponding)
    return self._responseTask.withLock { $0 != nil }
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
    await isolate(self.agentActor) { actor in
      var environment = environment
      environment.sessionId = self.id

      let graph = actor.graph(for: environment)

      environment.currentMessageId = CactusMessageID()
      let stream = CactusAgentStream<Output>(graph: graph)
      let request = CactusAgentRequest(input: message, environment: environment)

      self.withResponseTask {
        $0 = Task {
          let response = try await actor.agent.stream(request: request, into: stream.continuation)
          try stream.accept(finalResponse: response)
          self.withResponseTask { $0 = nil }
        }
      }
      return stream
    }
  }

  public func respond(to message: sending Input) async throws -> Output {
    let stream = await self.stream(for: message)
    return try await withTaskCancellationHandler {
      try await stream.collectFinalResponse()
    } onCancel: {
      stream.stop()
    }
  }

  private func withResponseTask(work: (inout Task<Void, any Error>?) -> Void) {
    self.observationRegistrar.withMutation(of: self, keyPath: \.isResponding) {
      self._responseTask.withLock { work(&$0) }
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
