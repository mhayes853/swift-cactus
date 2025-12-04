import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: Sendable {
  private let agentActor: AgentActor

  public var isResponding: Bool {
    false
  }

  public convenience init(
    modelSlug: String,
    functions: sending [any CactusFunction] = [],
    modelStore: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      .fromDirectory(slug: modelSlug),
      functions: functions,
      modelStore: modelStore,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    _ request: sending any CactusAgentModelRequest,
    functions: sending [any CactusFunction] = [],
    modelStore: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      CactusModelAgent(request, systemPrompt: systemPrompt)
        .functions(functions)
        .modelStore(modelStore)
    )
  }

  public convenience init(
    modelSlug: String,
    functions: sending [any CactusFunction] = [],
    modelStore: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .fromDirectory(slug: modelSlug),
      functions: functions,
      modelStore: modelStore,
      transcript: transcript
    )
  }

  public convenience init(
    _ request: sending any CactusAgentModelRequest,
    functions: sending [any CactusFunction] = [],
    modelStore: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      CactusModelAgent(request, transcript: transcript)
        .transcript(transcript)
        .functions(functions)
        .modelStore(modelStore)
    )
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

    init(_ agent: sending some CactusAgent<Input, Output>) {
      self.agent = agent
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: Observable {

}
