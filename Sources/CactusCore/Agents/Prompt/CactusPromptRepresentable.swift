// MARK: - CactusPromptRepresentable

public protocol CactusPromptRepresentable {
  associatedtype PromptContentFailure: Error
  var promptContent: CactusPromptContent { get throws(PromptContentFailure) }
}

// MARK: - Base Conformances

extension String: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    CactusPromptContent(text: self)
  }
}

extension CactusPromptContent: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    self
  }
}

extension Optional: CactusPromptRepresentable where Wrapped: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    get throws(Wrapped.PromptContentFailure) {
      if let unwrapped = self {
        try unwrapped.promptContent
      } else {
        CactusPromptContent()
      }
    }
  }
}
