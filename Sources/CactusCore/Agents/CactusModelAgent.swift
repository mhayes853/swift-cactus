import Foundation

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
>: CactusAgent {
  public init(_ model: CactusLanguageModel) {
  }

  public init(_ request: any CactusAgentModelRequest) {
  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
