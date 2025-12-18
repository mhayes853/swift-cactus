import Foundation

// MARK: - CactusModelSession

public final class CactusModelSession<
  Input: CactusPromptRepresentable & Sendable,
  Output: ConvertibleFromCactusResponse & Sendable
>: Sendable, Identifiable {
  public typealias Response = CactusAgentResponse<Output>

  private let agent: SingleModelAgent<Input, Output>
  private let session: CactusAgenticSession<SingleModelAgent<Input, Output>>

  private init(_ agent: SingleModelAgent<Input, Output>) {
    self.agent = agent
    self.session = CactusAgenticSession(agent)
  }

  public var id: UUID {
    self.session.id
  }

  public var scopedMemory: CactusMemoryStore {
    self.session.scopedMemory
  }

  public var isResponding: Bool {
    self.session.isResponding
  }

  public func stream(
    for message: Input,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> CactusAgentStream<Output> {
    self.session.stream(for: message, in: environment)
  }

  public func respond(
    to message: Input,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws -> Response {
    try await self.session.respond(to: message, in: environment)
  }

  public func configuredEnvironment(
    from environment: CactusEnvironmentValues
  ) -> CactusEnvironmentValues {
    self.session.configuredEnvironment(from: environment)
  }
}

// MARK: - Convenience Inits

extension CactusModelSession where Input: SendableMetatype {
  public convenience init(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) {
    let access = AgentModelAccess.direct(model)
    self.init(
      SingleModelAgent(
        access: access,
        transcript: transcript,
        functions: functions,
        systemPrompt: nil
      )
    )
  }

  public convenience init(
    _ loader: any CactusLanguageModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: nil
      )
    )
  }

  public convenience init(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    let access = AgentModelAccess.direct(model)
    self.init(
      SingleModelAgent(
        access: access,
        transcript: transcript,
        functions: functions,
        systemPrompt: systemPrompt
      )
    )
  }

  public convenience init(
    _ loader: any CactusLanguageModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: systemPrompt
      )
    )
  }

  public convenience init(
    _ model: sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(
      model,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    _ loader: any CactusLanguageModelLoader,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(
      loader,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModelSession: _Observable {}

// MARK: - FoundationModels Like APIs

extension CactusModelSession where Input: SendableMetatype {
  public func transcript(
    forceRefresh: Bool = false,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws -> CactusTranscript {
    let environment = self.configuredEnvironment(from: environment)
    let transcriptMemory = self.agent.$currentTranscript
    if transcriptMemory.isHydrated {
      guard forceRefresh else { return self.agent.currentTranscript }
      return try await transcriptMemory.refresh(in: environment)
    }
    return try await transcriptMemory.hydrate(in: environment)
  }

  public func prewarm(
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws {
    let environment = self.configuredEnvironment(from: environment)
    try await self.agent.access.prewarm(in: environment)
  }
}

// MARK: - Agent Wrapper

private struct SingleModelAgent<
  Input: CactusPromptRepresentable & Sendable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  @Memory var currentTranscript: CactusTranscript
  let access: AgentModelAccess
  private let functions: [any CactusFunction]
  private let systemPrompt: (@Sendable () -> (any CactusPromptRepresentable))?

  init(
    access: AgentModelAccess,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction],
    systemPrompt: (@Sendable () -> (any CactusPromptRepresentable))?
  ) {
    self.access = access
    self._currentTranscript = Memory(wrappedValue: CactusTranscript(), transcript)
    self.functions = functions
    self.systemPrompt = systemPrompt
  }

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<Input, Output> {
    CactusModelAgent(
      access: self.access,
      transcript: self.$currentTranscript.binding,
      systemPrompt: self.systemPrompt
    )
  }
}

// MARK: - Helpers

private let _defaultAgenticSessionTranscriptKey = "__SWIFT_CACTUS_DEFAULT_AGENT_TRANSCRIPT__"
