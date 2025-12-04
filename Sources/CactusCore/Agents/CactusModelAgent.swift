import Foundation

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  public init(
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
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
