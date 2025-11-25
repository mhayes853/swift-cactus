import Foundation

// MARK: - CactusPromptContent

public struct CactusPromptContent: Sendable {
  private enum Block: Sendable {
    case text(String)
    case separator(String)
    case images([URL])
    case representable(any CactusPromptRepresentable & Sendable)
  }

  private var blocks = [Block]()

  public init(text: String) {
    self.blocks.append(.text(text))
  }

  public init(images: [URL]) {
    self.blocks.append(.images(images))
  }

  public init() {}

  public init(_ content: some CactusPromptRepresentable & Sendable) {
    self.blocks.append(.representable(content))
  }

  public init<E: Error>(
    @CactusPromptBuilder build: () throws(E) -> some CactusPromptRepresentable & Sendable
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
  public struct MessageComponents: Sendable {
    private enum TextBlock: Sendable {
      case text(String)
      case separator(String)

      var text: String {
        switch self {
        case .text(let text): text
        case .separator(let separator): separator
        }
      }

      var isSeparator: Bool {
        switch self {
        case .separator: true
        default: false
        }
      }
    }

    private var textBlocks = [TextBlock]()

    public private(set) var text = ""
    public private(set) var images = [URL]()

    public init(content: CactusPromptContent) throws {
      for block in content.blocks {
        switch block {
        case .text(let text):
          self.textBlocks.append(.text(text))
        case .separator(let separator):
          if self.textBlocks.last?.isSeparator == true {
            self.textBlocks[self.textBlocks.count - 1] = .separator(separator)
          } else {
            self.textBlocks.append(.separator(separator))
          }
        case .images(let urls):
          self.images.append(contentsOf: urls)
        case .representable(let content):
          let components = try content.promptContent.messageComponents()

          // NB: Sub-TextBlocks are trimmed by this point, so we shouldn't have duplicate separators.
          self.textBlocks.append(contentsOf: components.textBlocks)
          self.images.append(contentsOf: components.images)
        }
      }

      self.textBlocks.trimming(while: \.isSeparator)
      for block in self.textBlocks {
        self.text += block.text
      }
    }
  }

  public func messageComponents() throws -> MessageComponents {
    try MessageComponents(content: self)
  }
}

extension CactusPromptContent.MessageComponents: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.text == rhs.text && lhs.images == rhs.images
  }
}

extension CactusPromptContent.MessageComponents: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.text)
    hasher.combine(self.images)
  }
}
