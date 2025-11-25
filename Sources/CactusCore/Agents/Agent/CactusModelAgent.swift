public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
>: CactusAgent {

  public init(slug: String, in directory: CactusModelsDirectory) {

  }

  public init(_ model: CactusLanguageModel) {

  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
