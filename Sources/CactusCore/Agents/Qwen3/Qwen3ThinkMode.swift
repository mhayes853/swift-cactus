public enum Qwen3ThinkMode: Hashable, Sendable, CactusPromptRepresentable {
  case think
  case noThink

  public var promptContent: CactusPromptContent {
    switch self {
    case .think: CactusPromptContent(text: "/think")
    case .noThink: CactusPromptContent(text: "/no_think")
    }
  }
}
