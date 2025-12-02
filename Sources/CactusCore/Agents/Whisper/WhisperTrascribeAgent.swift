import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  public init(_ model: CactusLanguageModel) {
  }

  public init(_ request: any CactusAgentModelRequest) {
  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: WhisperTranscribePrompt,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
