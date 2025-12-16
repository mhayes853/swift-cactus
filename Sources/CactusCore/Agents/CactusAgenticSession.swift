import Foundation
import Observation

// MARK: - CactusAgenticSession

@dynamicMemberLookup
public final class CactusAgenticSession<
  Agent: CactusAgent & SendableMetatype
>: Sendable, Identifiable {
  public typealias Response = CactusAgentResponse<Agent.Output>

  private let _agent: @Sendable () -> Agent
  private let observationRegistrar = _ObservationRegistrar()
  private let _responseStream = Lock<CactusAgentStream<Agent.Output>?>(nil)

  public let id = UUID()

  public let scopedMemory = CactusMemoryStore()

  public subscript<Value>(dynamicMember keyPath: KeyPath<Agent, Value>) -> Value {
    self._agent()[keyPath: keyPath]
  }

  public var isResponding: Bool {
    self.observationRegistrar.access(self, keyPath: \.isResponding)
    return self._responseStream.withLock { $0 != nil }
  }

  public init(_ agent: @autoclosure @escaping @Sendable () -> Agent) {
    self._agent = agent
  }

  public func stream(
    for message: sending Agent.Input,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> CactusAgentStream<Agent.Output> {
    var environment = environment
    environment.sessionId = self.id
    environment.sessionMemory = self.scopedMemory

    let request = UnsafeTransfer(
      value: CactusAgentRequest(input: message, environment: environment)
    )
    return self.withResponseTask {
      let stream = CactusAgentStream<Agent.Output> { continuation in
        let response = try await self._agent().stream(request: request.value, into: continuation)
        self.withResponseTask { $0 = nil }
        return response
      }
      $0 = stream
      return stream
    }
  }

  public func respond(
    to message: sending Agent.Input,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws -> Response {
    let stream = self.stream(for: message, in: environment)
    return try await withTaskCancellationHandler {
      try await stream.collectFinalResponse()
    } onCancel: {
      stream.stop()
    }
  }

  private func withResponseTask<T>(work: (inout CactusAgentStream<Agent.Output>?) -> T) -> T {
    self.observationRegistrar.withMutation(of: self, keyPath: \.isResponding) {
      self._responseStream.withLock { work(&$0) }
    }
  }
}

extension CactusAgenticSession where Agent.Input == Void {
  public func stream(
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> CactusAgentStream<Agent.Output> {
    self.stream(for: (), in: environment)
  }

  public func respond(
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws -> Response {
    try await self.respond(to: (), in: environment)
  }
}

// MARK: - Agent Actor

extension CactusAgenticSession {
  private final actor AgentActor {
    let agent: Agent

    init(_ agent: sending Agent) {
      self.agent = agent
    }

    func stream(
      request: CactusAgentRequest<Agent.Input>,
      into continuation: CactusAgentStream<Agent.Output>.Continuation
    ) async throws -> CactusAgentStream<Agent.Output>.Response {
      try await self.agent.stream(request: request, into: continuation)
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: _Observable {}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var sessionId: UUID {
    get { self[SessionIdKey.self] }
    set { self[SessionIdKey.self] = newValue }
  }

  private enum SessionIdKey: Key {
    static var defaultValue: UUID {
      UUID()
    }
  }

  public var sessionMemory: CactusMemoryStore {
    get { self[SessionMemoryStoreKey.self] }
    set { self[SessionMemoryStoreKey.self] = newValue }
  }

  private enum SessionMemoryStoreKey: Key {
    static var defaultValue: CactusMemoryStore {
      CactusMemoryStore()
    }
  }
}
