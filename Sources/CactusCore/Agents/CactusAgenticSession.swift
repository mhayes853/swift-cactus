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
    @CactusPromptBuilder systemPrompt: () -> CactusPromptContent
  ) {

  }

  public init(
    functions: [any CactusFunction] = [],
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
    try await self.stream(for: message, using: agent).collectResponse()
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: Observable {

}
