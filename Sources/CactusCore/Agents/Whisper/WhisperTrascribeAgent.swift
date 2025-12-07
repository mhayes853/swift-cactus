import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  private let access: AgentModelAccess

  public init(_ model: CactusLanguageModel) {
    self.init(access: .direct(model))
  }

  public init(_ loader: any CactusAgentModelLoader) {
    self.init(access: .loaded(loader))
  }

  private init(access: AgentModelAccess) {
    self.access = access
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
