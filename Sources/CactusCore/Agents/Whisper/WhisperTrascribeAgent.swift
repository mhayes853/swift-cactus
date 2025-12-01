import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  public init(modelURL: URL) {
    self.init(configuration: CactusLanguageModel.Configuration(modelURL: modelURL))
  }

  public init(configuration: CactusLanguageModel.Configuration) {

  }

  public init(_ model: CactusLanguageModel) {

  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: WhisperTranscribePrompt,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
