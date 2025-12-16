import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  private let access: AgentModelAccess

  public init(_ model: CactusLanguageModel) {
    self.init(access: .direct(model))
  }

  public init(_ loader: any CactusAudioModelLoader) {
    self.init(access: .loaded(loader))
  }

  private init(access: AgentModelAccess) {
    self.access = access
  }

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscription>.Continuation
  ) async throws -> CactusAgentStream<WhisperTranscription>.Response {
    let components = try request.input.promptContent(in: request.environment)
      .messageComponents(in: request.environment)
    let audioURL = request.input.audioURL
    let messageId = CactusMessageID()

    let baseOptions = request.environment.inferenceOptions
    let transcription = try await self.access.withModelAccess(in: request.environment) { model in
      let options = baseOptions ?? model.defaultTranscriptionOptions
      return try model.transcribe(
        audio: audioURL,
        prompt: components.text,
        options: options
      ) {
        token in
        let token = CactusStreamedToken(messageStreamId: messageId, stringValue: token)
        continuation.yield(token: token)
      }
    }

    return .collectTokensIntoOutput(
      metrics: [messageId: CactusMessageMetric(transcription: transcription)]
    )
  }
}
