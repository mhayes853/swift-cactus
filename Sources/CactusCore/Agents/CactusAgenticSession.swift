import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession {
  public var isResponding: Bool {
    false
  }

  public var transcript: CactusTranscript {
    CactusTranscript()
  }

  public init(
    functions: [any CactusFunction] = [],
    modelStore: any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: () -> CactusPromptContent
  ) {

  }

  public init(
    functions: [any CactusFunction] = [],
    modelStore: any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {

  }

  public func stream<Input, Output>(
    for message: Input,
    using agent: some CactusAgent<Input, Output>
  ) -> CactusAgentStream<Output> {
    CactusAgentStream()
  }

  public func respond<Input, Output>(
    to message: Input,
    using agent: some CactusAgent<Input, Output>
  ) async throws -> Output {
    let stream = self.stream(for: message, using: agent)
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: Observable {

}
