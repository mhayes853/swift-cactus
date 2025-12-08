import Foundation
import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<
  Input,
  Output: ConvertibleFromCactusResponse
>: Sendable, Identifiable {
  private let agentActor: AgentActor

  public let id = UUID()

  public var isResponding: Bool {
    false
  }

  public init(_ agent: sending some CactusAgent<Input, Output>) {
    self.agentActor = AgentActor(agent)
  }

  public func stream(for message: Input) -> CactusAgentStream<Output> {
    CactusAgentStream()
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
extension CactusAgenticSession: Observable {

}
