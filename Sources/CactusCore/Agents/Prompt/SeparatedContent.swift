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

  public var promptContent: CactusPromptContent {
    get throws {
      try PromptSeparatorLocal.$current.withValue(self.separator) {
        try self.content.promptContent
      }
    }
  }
}

// MARK: - CactusPromptSeparatorLocal

enum PromptSeparatorLocal {
  @TaskLocal static var current = "\n"
}
