// MARK: - SeparatedContent

extension CactusPromptRepresentable {
  public func separated(by separator: String) -> _SeparatedContent<Self> {
    _SeparatedContent(content: self, separator: separator)
  }
}

public struct _SeparatedContent<
  Content: CactusPromptRepresentable
>: CactusPromptRepresentable {
  let content: Content
  let separator: String

  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Content.PromptContentFailure) -> CactusPromptContent {
    var env = environment
    env.promptSeparator = self.separator
    return try self.content.promptContent(in: env)
  }
}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var promptSeparator: String {
    get { self[PromptSeparatorKey.self] }
    set { self[PromptSeparatorKey.self] = newValue }
  }

  private enum PromptSeparatorKey: Key {
    static let defaultValue = "\n"
  }
}
