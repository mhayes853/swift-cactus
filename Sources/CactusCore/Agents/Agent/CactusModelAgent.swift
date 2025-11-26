import Foundation

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
>: CactusAgent {
  public init(_ model: CactusLanguageModel) {

  }

  public init(url: URL) {
    self.init(configuration: CactusLanguageModel.Configuration(modelURL: url))
  }

  public init(configuration: CactusLanguageModel.Configuration) {

  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
