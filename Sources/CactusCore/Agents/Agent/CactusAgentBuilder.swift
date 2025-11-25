@resultBuilder
public enum CactusAgentBuilder<Input: CactusPromptRepresentable, Output: ConvertibleFromJSONValue> {
  public static func buildBlock() -> EmptyAgent<Input, Output> {
    EmptyAgent()
  }
}
