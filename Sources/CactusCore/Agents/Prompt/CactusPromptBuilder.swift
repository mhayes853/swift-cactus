@resultBuilder
public struct CactusPromptBuilder {
  public static func buildBlock<each P: CactusPromptRepresentable & Sendable>(
    _ components: repeat each P
  ) -> CactusPromptContent {
    var prompt = CactusPromptContent()
    for component in repeat each components {
      prompt.join(with: CactusPromptContent(component))
    }
    return prompt
  }
}
