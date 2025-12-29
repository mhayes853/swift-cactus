import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable & Sendable,
  Output: ConvertibleFromCactusResponse & Sendable
>: CactusAgent {
  @MemoryBinding private var transcript: CactusTranscript
  private let access: AgentModelAccess
  private let systemPrompt: (@Sendable () -> any CactusPromptRepresentable)?

  public init(
    _ model: sending CactusLanguageModel,
    transcript: MemoryBinding<CactusTranscript>
  ) {
    self.init(
      access: .direct(model),
      transcript: transcript,
      systemPrompt: nil
    )
  }

  public init(
    _ loader: any CactusLanguageModelLoader,
    transcript: MemoryBinding<CactusTranscript>
  ) {
    self.init(
      access: .loaded(loader),
      transcript: transcript,
      systemPrompt: nil
    )
  }

  public init(
    _ model: sending CactusLanguageModel,
    transcript: MemoryBinding<CactusTranscript>,
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .direct(model),
      transcript: transcript,
      systemPrompt: systemPrompt
    )
  }

  public init(
    _ loader: any CactusLanguageModelLoader,
    transcript: MemoryBinding<CactusTranscript>,
    @CactusPromptBuilder systemPrompt: @escaping @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(
      access: .loaded(loader),
      transcript: transcript,
      systemPrompt: systemPrompt
    )
  }

  init(
    access: AgentModelAccess,
    transcript: MemoryBinding<CactusTranscript>,
    systemPrompt: (@Sendable () -> any CactusPromptRepresentable)?
  ) {
    self._transcript = transcript
    self.access = access
    self.systemPrompt = systemPrompt
  }

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    var transcript = try self.transcript(in: request.environment)
    let userMessageId = CactusMessageID()

    let userMessage = try request.input.chatMessage(role: .user, in: request.environment)
    transcript.append(CactusTranscript.Element(id: userMessageId, message: userMessage))

    let chatMessages = transcript.map(\.message)
    let baseInferenceOptions = request.environment.inferenceOptions

    let (completion, inferenceOptions) = try await self.access
      .withModelAccess(in: request.environment) { model in
        let inferenceOptions = baseInferenceOptions ?? model.defaultChatCompletionOptions
        let completion = try model.chatCompletion(
          messages: chatMessages,
          options: inferenceOptions
        ) { token in
          let token = CactusStreamedToken(messageStreamId: userMessageId, stringValue: token)
          continuation.yield(token: token)
        }
        return (completion, inferenceOptions)
      }

    let response = cleanResponse(completion.response, stopSequences: inferenceOptions.stopSequences)
    transcript.append(
      CactusTranscript.Element(id: CactusMessageID(), message: .assistant(response))
    )

    self.transcript = transcript

    return .collectTokensIntoOutput(
      metrics: [userMessageId: CactusMessageMetric(completion: completion)]
    )
  }

  private func transcript(
    in environment: CactusEnvironmentValues
  ) throws -> CactusTranscript {
    guard let systemPrompt else { return self.transcript }

    var transcript = self.transcript
    let systemMessage = try systemPrompt().chatMessage(role: .system, in: environment)

    if let systemIndex = transcript.firstIndex(where: { $0.message.role == .system }) {
      transcript[systemIndex].message = systemMessage
    } else {
      var elements = [CactusTranscript.Element(id: CactusMessageID(), message: systemMessage)]
      elements.append(contentsOf: transcript)
      transcript = CactusTranscript(elements: elements)
    }
    self.transcript = transcript
    return transcript
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
