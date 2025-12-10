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

  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "WhisperTranscribeAgent (\(self.access.slug(in: environment)))"
      )
    )
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws -> CactusAgentResponse<WhisperTranscriptionResponse> {
    let components = try request.input.promptContent(in: request.environment)
      .messageComponents(in: request.environment)
    let audioURL = request.input.audioURL
    let messageId = request.environment.currentMessageId ?? CactusMessageID()

    try await self.access.withModelAccess(in: request.environment) { model in
      _ = try model.transcribe(audio: audioURL, prompt: components.text) { token in
        continuation.yield(
          token: CactusStreamedToken(messageStreamId: messageId, stringValue: token)
        )
      }
    }

    return .collectTokensIntoOutput
  }
}
