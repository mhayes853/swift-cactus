/// Controls whether compatible models should produce internal reasoning output.
public enum ReasoningMode: String, Hashable, Sendable {
  case think = "/think"
  case noThink = "/no_think"
}

extension CactusPromptRepresentable {
  /// Prepends a reasoning-mode command to the beginning of prompt content.
  ///
  /// ```swift
  /// let content = CactusPromptContent {
  ///   "Explain this briefly"
  /// }
  /// .reasoningMode(.noThink) // Appends /no_think to the beginning of the prompt.
  /// ```
  ///
  /// - Parameter mode: The reasoning mode command to prepend.
  /// - Returns: A prompt wrapper that prepends the selected reasoning-mode command.
  public func reasoningMode(_ mode: ReasoningMode) -> _ReasoningModeContent<Self> {
    _ReasoningModeContent(content: self, mode: mode)
  }
}

/// A prompt wrapper that prepends a reasoning-mode command before nested prompt content.
public struct _ReasoningModeContent<Content: CactusPromptRepresentable>: CactusPromptRepresentable {
  let content: Content
  let mode: ReasoningMode

  public var promptContent: CactusPromptContent {
    get throws {
      CactusPromptContent {
        self.mode.rawValue
        self.content
      }
    }
  }
}
