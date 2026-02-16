extension CactusPromptRepresentable {
  /// Overrides the separator used while joining nested prompt content.
  ///
  /// ```swift
  /// let content = CactusPromptContent {
  ///   GroupContent {
  ///     "A"
  ///     "B"
  ///     "C"
  ///   }
  ///   .separated(by: ", ")
  /// }
  ///
  /// let components = try content.messageComponents()
  /// // components.text == "A, B, C"
  /// ```
  ///
  /// - Parameter separator: The separator used to join nested text fragments.
  /// - Returns: A prompt wrapper that applies the separator to its subtree.
  public func separated(by separator: String) -> _SeparatedContent<Self> {
    _SeparatedContent(content: self, separator: separator)
  }
}

/// A prompt wrapper that applies a custom separator to nested prompt joins.
public struct _SeparatedContent<Content: CactusPromptRepresentable>: CactusPromptRepresentable {
  let content: Content
  let separator: String

  public var promptContent: CactusPromptContent {
    get throws {
      try _CactusPromptContext.$separator.withValue(self.separator) {
        try self.content.promptContent
      }
    }
  }
}
