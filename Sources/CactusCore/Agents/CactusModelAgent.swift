import Foundation

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
>: CactusAgent {
  public init(_ model: CactusLanguageModel) {
  }

  public init(_ request: any CactusAgentModelRequest) {
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
