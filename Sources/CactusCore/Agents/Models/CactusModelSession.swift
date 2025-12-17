import Foundation

// MARK: - CactusModelSession

public typealias CactusModelSession<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse & Sendable
> = CactusAgenticSession<SingleModelAgent<Input, Output>>

// MARK: - Convenience Inits

extension CactusModelSession {
  public convenience init<Input: SendableMetatype, Output>(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) where Agent == SingleModelAgent<Input, Output> {
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

  public convenience init<Input: SendableMetatype, Output>(
    _ loader: any CactusLanguageModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = []
  ) where Agent == SingleModelAgent<Input, Output> {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: nil
      )
    )
  }

  public convenience init<Input: SendableMetatype, Output>(
    _ model: sending CactusLanguageModel,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) where Agent == SingleModelAgent<Input, Output> {
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

  public convenience init<Input: SendableMetatype, Output>(
    _ loader: any CactusLanguageModelLoader,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) where Agent == SingleModelAgent<Input, Output> {
    self.init(
      SingleModelAgent(
        access: .loaded(loader),
        transcript: transcript,
        functions: functions,
        systemPrompt: systemPrompt
      )
    )
  }

  public convenience init<Input: SendableMetatype, Output>(
    _ model: sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) where Agent == SingleModelAgent<Input, Output> {
    self.init(
      model,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }

  public convenience init<Input: SendableMetatype, Output>(
    _ loader: any CactusLanguageModelLoader,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) where Agent == SingleModelAgent<Input, Output> {
    self.init(
      loader,
      transcript: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      functions: functions,
      systemPrompt: systemPrompt
    )
  }
}

// MARK: - Properties

extension CactusModelSession {
  public func transcript<Input: SendableMetatype, Output>(
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) async throws -> CactusTranscript where Agent == SingleModelAgent<Input, Output> {
    let environment = self.configuredEnvironment(from: environment)
    if self.$transcript.isHydrated {
      return self.agent.transcript
    }
    return try await self.$transcript.hydrate(in: environment)
  }
}

// MARK: - Agent Wrapper

public struct SingleModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  @Memory var transcript: CactusTranscript
  private let access: AgentModelAccess
  private let functions: [any CactusFunction]
  private let systemPrompt: (@Sendable () -> (any CactusPromptRepresentable))?

  init(
    access: AgentModelAccess,
    transcript: some CactusMemoryLocation<CactusTranscript>,
    functions: [any CactusFunction],
    systemPrompt: (@Sendable () -> (any CactusPromptRepresentable))?
  ) {
    self.access = access
    self._transcript = Memory(wrappedValue: CactusTranscript(), transcript)
    self.functions = functions
    self.systemPrompt = systemPrompt
  }

  public func body(environment: CactusEnvironmentValues) -> some CactusAgent<Input, Output> {
    CactusModelAgent(
      access: self.access,
      transcript: self.$transcript.binding,
      systemPrompt: systemPrompt
    )
  }
}

// MARK: - Helpers

package let _defaultAgenticSessionTranscriptKey = "__SWIFT_CACTUS_DEFAULT_AGENT_TRANSCRIPT__"
