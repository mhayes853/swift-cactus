public struct TransformInput<
  Input: CactusPromptRepresentable,
  Child: CactusAgent
>: CactusAgent {
  private let child: Child
  private let transformInput: (Input) throws -> Child.Input

  public init(
    transformInput: @escaping (Input) throws -> Child.Input,
    @CactusAgentBuilder<Child.Input, Child.Output> agent: () -> Child,
  ) where Child.Output == Output {
    self.child = agent()
    self.transformInput = transformInput
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Child.Output>.Continuation
  ) async throws {
  }
}

struct SomeInput: CactusPromptRepresentable {
  let transcription: WhisperTranscribePrompt

  func promptContent(in environment: CactusEnvironmentValues) -> CactusPromptContent {
    self.transcription.promptContent(in: environment)
  }
}
