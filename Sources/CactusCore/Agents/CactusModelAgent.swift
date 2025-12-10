import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  private let access: AgentModelAccess
  private let initialContent: InitialContent

  private enum InitialContent {
    case systemPrompt(CactusPromptContent)
    case transcript(CactusTranscript)
  }

  public init(_ model: CactusLanguageModel, transcript: CactusTranscript) {
    self.init(access: .direct(model), initialContent: .transcript(transcript))
  }

  public init(_ loader: any CactusAgentModelLoader, transcript: CactusTranscript) {
    self.init(access: .loaded(loader), initialContent: .transcript(transcript))
  }

  public init(
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .direct(model),
      initialContent: .systemPrompt(CactusPromptContent(systemPrompt()))
    )
  }

  public init(
    _ loader: any CactusAgentModelLoader,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .loaded(loader),
      initialContent: .systemPrompt(CactusPromptContent(systemPrompt()))
    )
  }

  private init(access: AgentModelAccess, initialContent: InitialContent) {
    self.access = access
    self.initialContent = initialContent
  }

  public func build(
    graph: inout CactusAgentGraph,
    at nodeId: CactusAgentGraph.Node.ID,
    in environment: CactusEnvironmentValues
  ) {
    graph.appendChild(
      to: nodeId,
      fields: CactusAgentGraph.Node.Fields(
        label: "CactusModelAgent (\(self.access.slug(in: environment)))"
      )
    )
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    let messages = try self.initialMessages(in: request.environment)
    let messageId = request.environment.currentMessageId ?? CactusMessageID()

    let completion = try await self.access.withModelAccess(in: request.environment) { model in
      try model.chatCompletion(messages: messages) { token in
        continuation.yield(
          token: CactusStreamedToken(messageStreamId: messageId, stringValue: token)
        )
      }
    }
    return .collectTokensIntoOutput(
      metrics: [messageId: CactusMessageMetric(completion: completion)]
    )
  }

  private func initialMessages(
    in environment: CactusEnvironmentValues
  ) throws -> [CactusLanguageModel.ChatMessage] {
    switch self.initialContent {
    case .systemPrompt(let prompt):
      [
        CactusLanguageModel.ChatMessage(
          role: .system,
          components: try prompt.messageComponents(in: environment)
        )
      ]
    case .transcript(let transcript):
      transcript.map(\.message)
    }
  }
}
