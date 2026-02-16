/// Controls whether compatible models should produce internal reasoning output.
public enum ThinkMode: Hashable, Sendable {
  case think
  case noThink

  fileprivate var promptCommand: String {
    switch self {
    case .think: "/think"
    case .noThink: "/no_think"
    }
  }
}

extension CactusPromptRepresentable {
  /// Prepends a think-mode command to the beginning of prompt content.
  ///
  /// ```swift
  /// let content = CactusPromptContent {
  ///   "Explain this briefly"
  /// }
  /// .thinkMode(.noThink) // Appends /no_think to the beginning of the prompt.
  /// ```
  ///
  /// - Parameter mode: The think mode command to prepend.
  /// - Returns: A prompt wrapper that prepends the selected think-mode command.
  public func thinkMode(_ mode: ThinkMode) -> _ThinkModeContent<Self> {
    _ThinkModeContent(content: self, mode: mode)
  }
}

/// A prompt wrapper that prepends a think-mode command before nested prompt content.
public struct _ThinkModeContent<Content: CactusPromptRepresentable>: CactusPromptRepresentable {
  let content: Content
  let mode: ThinkMode

  public var promptContent: CactusPromptContent {
    get throws {
      CactusPromptContent {
        self.mode.promptCommand
        self.content
      }
    }
  }
}
