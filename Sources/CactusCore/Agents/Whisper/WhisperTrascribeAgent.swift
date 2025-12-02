import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  public init(_ model: CactusLanguageModel) {
  }

  public init(_ request: any CactusAgentModelRequest) {
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
