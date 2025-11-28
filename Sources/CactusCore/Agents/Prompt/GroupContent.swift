public struct GroupContent<
  Content: CactusPromptRepresentable
>: CactusPromptRepresentable {
  private let content: Content

  public var promptContent: CactusPromptContent {
    get throws { try self.content.promptContent }
  }

  public init(@CactusPromptBuilder builder: () -> Content) {
    self.content = builder()
  }
}
