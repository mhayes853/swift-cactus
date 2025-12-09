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

  public func graph(for message: Input) -> CactusAgentGraph {
    fatalError()
  }

  public func stream(for message: Input) -> CactusAgentStream<Output> {
    CactusAgentStream(graph: self.graph(for: message))
  }

  public func respond(to message: Input) async throws -> Output {
    let stream = self.stream(for: message)
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
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: _Observable {

}
