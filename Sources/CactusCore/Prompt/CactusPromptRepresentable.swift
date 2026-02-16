// MARK: - CactusPromptRepresentable

/// A type that can be converted into ``CactusPromptContent``.
public protocol CactusPromptRepresentable {
  /// The prompt content representation of this value.
  var promptContent: CactusPromptContent { get throws }
}

// MARK: - Language Model Message

extension CactusPromptRepresentable {
  /// Converts prompt content to a language-model chat message.
  ///
  /// - Parameter role: The role to assign to the generated message.
  /// - Returns: A chat message with text and optional images.
  public func chatMessage(
    role: CactusLanguageModel.MessageRole
  ) throws -> CactusLanguageModel.ChatMessage {
    let components = try self.promptContent.messageComponents()
    return CactusLanguageModel.ChatMessage(role: role, components: components)
  }
}

extension CactusLanguageModel.ChatMessage {
  /// Creates a chat message from prompt message components.
  ///
  /// - Parameters:
  ///   - role: The message role.
  ///   - components: Prompt-derived message components.
  public init(
    role: CactusLanguageModel.MessageRole,
    components: CactusPromptContent.MessageComponents
  ) {
    self.init(
      role: role,
      content: components.text,
      images: components.images.isEmpty ? nil : components.images
    )
  }
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
    get throws {
      if let unwrapped = self {
        try unwrapped.promptContent
      } else {
        CactusPromptContent()
      }
    }
  }
}
