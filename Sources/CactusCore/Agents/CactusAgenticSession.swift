import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<Input, Output: ConvertibleFromCactusResponse>: Sendable {
  private let agentActor: AgentActor

  public var isResponding: Bool {
    false
  }

  public func prewarmModel(request: sending CactusAgentModelRequest) async throws {
    try await self.agentActor.prewarmModel(request: request)
  }

  public init(
    _ agent: sending some CactusAgent<Input, Output>,
    store: sending some CactusAgentModelStore = SessionModelStore()
  ) {
    self.agentActor = AgentActor(agent, store: store)
  }

  public func stream(for message: Input) -> CactusAgentStream<Output> {
    CactusAgentStream()
  }

  public func respond(to message: Input) async throws -> Output {
    let stream = self.stream(for: message)
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }
}

// MARK: - Agent Actor

extension CactusAgenticSession {
  private final actor AgentActor {
    private let agent: any CactusAgent<Input, Output>
    private let store: any CactusAgentModelStore

    init(
      _ agent: sending some CactusAgent<Input, Output>,
      store: sending some CactusAgentModelStore
    ) {
      self.agent = agent
      self.store = store
    }

    func prewarmModel(request: sending CactusAgentModelRequest) async throws {
      try await self.store.prewarmModel(request: request)
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: Observable {

}
