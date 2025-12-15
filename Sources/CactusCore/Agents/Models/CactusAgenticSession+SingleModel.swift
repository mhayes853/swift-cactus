import Foundation

// MARK: - Convenience Inits

extension CactusAgenticSession
where Input: CactusPromptRepresentable, Output: ConvertibleFromCactusResponse {
  public convenience init(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) {
    self.init(
      SingleModelAgent(
        access: .direct(model),
        transcript: transcript,
        functions: functions,
        systemPrompt: { nil }
      )
    )
  }

  public convenience init(
    _ loader: any CactusAgentModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: { nil }
      )
    )
  }

  public convenience init(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      SingleModelAgent(
        access: .direct(model),
        transcript: transcript,
        functions: functions,
        systemPrompt: { systemPrompt() }
      )
    )
  }

  public convenience init(
    _ loader: any CactusAgentModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: { systemPrompt() }
      )
    )
  }

  public convenience init(
    _ model: sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      model,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    _ loader: any CactusAgentModelLoader,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      loader,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }
}

// MARK: - Agent Wrapper

private struct SingleModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  @Memory private var transcript: CactusTranscript
  private let access: AgentModelAccess
  private let functions: [any CactusFunction]
  private let systemPrompt: CactusPromptContent?

  init(
    access: AgentModelAccess,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction],
    systemPrompt: () -> (any CactusPromptRepresentable)?
  ) {
    self.access = access
    self._transcript = Memory(wrappedValue: CactusTranscript(), transcript)
    self.functions = functions
    self.systemPrompt = systemPrompt().map { CactusPromptContent($0) }
  }

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<Input, Output> {
    CactusModelAgent(
      access: self.access,
      transcript: self.$transcript.binding,
      systemPrompt: systemPrompt
    )
  }
}

// MARK: - Helpers

package let _defaultAgenticSessionTranscriptKey = "__SWIFT_CACTUS_DEFAULT_AGENT_TRANSCRIPT__"
