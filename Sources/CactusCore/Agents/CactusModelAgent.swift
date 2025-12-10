import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  private let access: AgentModelAccess
  private let initialContent: InitialContent
  private let transcriptKey: CactusTranscript.Key?

  private enum InitialContent {
    case systemPrompt(CactusPromptContent)
    case transcript(CactusTranscript)
  }

  public init(
    _ model: CactusLanguageModel,
    transcriptKey: CactusTranscript.Key? = nil,
    initialTranscript: CactusTranscript
  ) {
    self.init(
      access: .direct(model),
      initialContent: .transcript(initialTranscript),
      transcriptKey: transcriptKey
    )
  }

  public init(
    _ loader: any CactusAgentModelLoader,
    transcriptKey: CactusTranscript.Key? = nil,
    initialTranscript: CactusTranscript,
  ) {
    self.init(
      access: .loaded(loader),
      initialContent: .transcript(initialTranscript),
      transcriptKey: transcriptKey
    )
  }

  public init(
    _ model: CactusLanguageModel,
    transcriptKey: CactusTranscript.Key? = nil,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .direct(model),
      initialContent: .systemPrompt(CactusPromptContent(systemPrompt())),
      transcriptKey: transcriptKey
    )
  }

  public init(
    _ loader: any CactusAgentModelLoader,
    transcriptKey: CactusTranscript.Key? = nil,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .loaded(loader),
      initialContent: .systemPrompt(CactusPromptContent(systemPrompt())),
      transcriptKey: transcriptKey
    )
  }

  private init(
    access: AgentModelAccess,
    initialContent: InitialContent,
    transcriptKey: CactusTranscript.Key?
  ) {
    self.access = access
    self.initialContent = initialContent
    self.transcriptKey = transcriptKey
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
    var transcript = try await self.transcript(in: request.environment)
    let currentMessageId = request.environment.currentMessageId ?? CactusMessageID()

    let userMessage = try request.input.chatMessage(role: .user, in: request.environment)
    transcript.append(CactusTranscript.Element(id: currentMessageId, message: userMessage))

    let chatMessages = transcript.map(\.message)
    let baseInferenceOptions = request.environment.inferenceOptions

    let (completion, inferenceOptions) = try await self.access
      .withModelAccess(in: request.environment) { model in
        let inferenceOptions = baseInferenceOptions ?? model.defaultChatCompletionOptions
        let completion = try model.chatCompletion(
          messages: chatMessages,
          options: inferenceOptions
        ) { token in
          let token = CactusStreamedToken(messageStreamId: currentMessageId, stringValue: token)
          continuation.yield(token: token)
        }
        return (completion, inferenceOptions)
      }

    let response = cleanResponse(completion.response, stopSequences: inferenceOptions.stopSequences)
    transcript.append(
      CactusTranscript.Element(id: CactusMessageID(), message: .assistant(response))
    )

    if let transcriptKey {
      try await request.environment.transcriptStore.save(
        transcript: transcript,
        forKey: transcriptKey
      )
    }

    return .collectTokensIntoOutput(
      metrics: [currentMessageId: CactusMessageMetric(completion: completion)]
    )
  }

  private nonisolated(nonsending) func transcript(
    in environment: CactusEnvironmentValues
  ) async throws -> CactusTranscript {
    if let transcriptKey,
      let transcript = try await environment.transcriptStore.transcript(forKey: transcriptKey)
    {
      return transcript
    }
    switch self.initialContent {
    case .systemPrompt(let prompt):
      return CactusTranscript(
        elements: CollectionOfOne(
          CactusTranscript.Element(
            id: CactusMessageID(),
            message: CactusLanguageModel.ChatMessage(
              role: .system,
              components: try prompt.messageComponents(in: environment)
            )
          )
        )
      )
    case .transcript(let transcript):
      return transcript
    }
  }
}

// MARK: - Helpers

private func cleanResponse(_ response: String, stopSequences: [String]) -> String {
  for sequence in stopSequences {
    if response.hasSuffix(sequence) {
      return String(response.dropLast(sequence.count))
    }
  }
  return response
}
