import Foundation

// MARK: - CactusPromptContent

public struct CactusPromptContent: Sendable {
  public var content: String
  public var images: [URL]

  public init(content: String, images: [URL] = []) {
    self.content = content
    self.images = images
  }

  public init(_ content: some CactusPromptRepresentable) {
    fatalError()
  }

  public init<E: Error>(
    @CactusPromptBuilder build: () throws(E) -> some CactusPromptRepresentable
  ) throws(E) {
    fatalError()
  }
}

// MARK: - CactusPromptContent

extension CactusPromptContent: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(content: value)
  }
}
