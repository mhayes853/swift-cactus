@resultBuilder
public enum CactusAgentBuilder<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
> {
  public static func buildBlock() -> EmptyAgent<Input, Output> {
    EmptyAgent()
  }
}
