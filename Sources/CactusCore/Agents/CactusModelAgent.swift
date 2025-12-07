import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  private let access: AgentModelAccess
  private let transcript: CactusTranscript

  public init(_ model: CactusLanguageModel, transcript: CactusTranscript) {
    self.init(access: .direct(model), transcript: transcript)
  }

  public init(_ loader: any CactusAgentModelLoader, transcript: CactusTranscript) {
    self.init(access: .loaded(loader), transcript: transcript)
  }

  public init(
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(access: .direct(model), transcript: CactusTranscript())
  }

  public init(
    _ loader: any CactusAgentModelLoader,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(loader, transcript: CactusTranscript())
  }

  private init(access: AgentModelAccess, transcript: CactusTranscript) {
    self.access = access
    self.transcript = transcript
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
