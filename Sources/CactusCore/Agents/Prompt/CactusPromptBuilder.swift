@resultBuilder
public struct CactusPromptBuilder {
  public static func buildBlock<each P>(_ components: repeat each P) -> CactusPromptContent
  where repeat each P: CactusPromptRepresentable {
    fatalError()
  }
}
