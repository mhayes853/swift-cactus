// MARK: - CactusPromptRepresentable

public protocol CactusPromptRepresentable: Sendable {
  associatedtype PromptContentFailure: Error
  func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(PromptContentFailure) -> CactusPromptContent
}

// MARK: - Language Model Message

extension CactusPromptRepresentable {
  public func chatMessage(
    role: CactusLanguageModel.MessageRole,
    in environment: CactusEnvironmentValues
  ) throws -> CactusLanguageModel.ChatMessage {
    let components = try self.promptContent(in: environment).messageComponents(in: environment)
    return CactusLanguageModel.ChatMessage(
      role: role,
      content: components.text,
      images: components.images.isEmpty ? nil : components.images
    )
  }
}

// MARK: - Base Conformances

extension String: CactusPromptRepresentable {
  public func promptContent(
    in environment: CactusEnvironmentValues
  ) -> CactusPromptContent {
    CactusPromptContent(text: self)
  }
}

extension CactusPromptContent: CactusPromptRepresentable {
  public func promptContent(
    in environment: CactusEnvironmentValues
  ) -> CactusPromptContent {
    self
  }
}

extension Optional: CactusPromptRepresentable where Wrapped: CactusPromptRepresentable {
  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Wrapped.PromptContentFailure) -> CactusPromptContent {
    if let unwrapped = self {
      try unwrapped.promptContent(in: environment)
    } else {
      CactusPromptContent()
    }
  }
}
