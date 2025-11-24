// MARK: - CactusPromptRepresentable

public protocol CactusPromptRepresentable {
  var promptContent: CactusPromptContent { get }
}

// MARK: - Base Conformances

extension String: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    CactusPromptContent(stringLiteral: self)
  }
}

extension CactusPromptContent: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    self
  }
}
