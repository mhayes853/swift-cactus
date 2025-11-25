import Foundation

// MARK: - CactusPromptContent

public struct CactusPromptContent {
  private enum Block {
    case text(String)
    case separator(String)
    case images([URL])
    case representable(any CactusPromptRepresentable)
  }

  private var blocks = [Block]()

  public init(text: String) {
    self.blocks.append(.text(text))
  }

  public init(images: [URL]) {
    self.blocks.append(.images(images))
  }

  public init() {}

  public init(_ content: some CactusPromptRepresentable) {
    self.blocks.append(.representable(content))
  }

  public init<E: Error>(
    @CactusPromptBuilder build: () throws(E) -> some CactusPromptRepresentable
  ) throws(E) {
    self.blocks.append(.representable(try build()))
  }
}

// MARK: - Join

extension CactusPromptContent {
  public func joined(with other: Self, separator: String = "\n") -> Self {
    var content = self
    content.join(with: other, separator: separator)
    return content
  }

  public mutating func join(with other: Self, separator: String = "\n") {
    self.blocks.append(.separator(separator))
    self.blocks.append(contentsOf: other.blocks)
  }
}

// MARK: - MessageComponents

extension CactusPromptContent {
  public struct MessageComponents: Hashable, Sendable {
    public private(set) var text = ""
    public private(set) var images = [URL]()

    public init(content: CactusPromptContent) throws {
      var currentSeparator: String?
      for block in content.blocks {
        switch block {
        case .text(let text):
          self.appendText(text, currentSeparator: &currentSeparator)
        case .separator(let separator):
          guard !self.text.isEmpty else { continue }
          currentSeparator = separator
        case .images(let urls):
          self.images.append(contentsOf: urls)
        case .representable(let representable):
          let components = try representable.promptContent.messageComponents()
          self.appendText(components.text, currentSeparator: &currentSeparator)
          self.images.append(contentsOf: components.images)
        }
      }
    }

    private mutating func appendText(_ text: String, currentSeparator: inout String?) {
      if let separator = currentSeparator {
        self.text += separator
        currentSeparator = nil
      }
      self.text += text
    }
  }

  public func messageComponents() throws -> MessageComponents {
    try MessageComponents(content: self)
  }
}
