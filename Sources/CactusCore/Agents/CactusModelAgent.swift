import Foundation

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  public init(_ model: CactusLanguageModel, transcript: CactusTranscript) {
  }

  public init(modelSlug: String, transcript: CactusTranscript) {
    self.init(.fromDirectory(slug: modelSlug), transcript: transcript)
  }

  public init(_ request: any CactusAgentModelRequest, transcript: CactusTranscript) {
  }

  public init(
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
  }

  public init(
    modelSlug: String,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(.fromDirectory(slug: modelSlug), systemPrompt: systemPrompt)
  }

  public init(
    _ request: any CactusAgentModelRequest,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
