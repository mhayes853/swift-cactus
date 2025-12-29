public struct GroupContent<
  Content: CactusPromptRepresentable
>: CactusPromptRepresentable {
  private let content: Content

  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Content.PromptContentFailure) -> CactusPromptContent {
    try self.content.promptContent(in: environment)
  }

  public init(@CactusPromptBuilder builder: () -> Content) {
    self.content = builder()
  }
}
