import Foundation

// MARK: - CactusMessageComponents

public struct CactusMessageComponents: Hashable, Sendable {
  public var text: String
  public var images: [URL]

  public init(text: String, images: [URL] = [URL]()) {
    self.text = text
    self.images = images
  }
}

// MARK: - ChatMessage

extension CactusLanguageModel.ChatMessage {
  public init(role: CactusLanguageModel.MessageRole, components: CactusMessageComponents) {
    self.init(
      role: role,
      content: components.text,
      images: components.images.isEmpty ? nil : components.images
    )
  }
}
