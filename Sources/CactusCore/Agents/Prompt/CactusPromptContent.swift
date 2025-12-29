import Foundation

// MARK: - CactusPromptContent

public struct CactusPromptContent: Sendable {
  private enum Block: Sendable {
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
  public func messageComponents(
    in environment: CactusEnvironmentValues
  ) throws -> CactusMessageComponents {
    var components = CactusMessageComponents(text: "")
    var currentSeparator: String?
    for block in self.blocks {
      switch block {
      case .text(let text):
        components.appendText(text, currentSeparator: &currentSeparator)
      case .separator(let separator):
        guard !components.text.isEmpty else { continue }
        currentSeparator = separator
      case .images(let urls):
        components.images.append(contentsOf: urls)
      case .representable(let representable):
        let subcomponents = try representable.promptContent(in: environment)
          .messageComponents(in: environment)
        components.appendText(subcomponents.text, currentSeparator: &currentSeparator)
        components.images.append(contentsOf: subcomponents.images)
      }
    }
    return components
  }
}

extension CactusMessageComponents {
  fileprivate mutating func appendText(_ text: String, currentSeparator: inout String?) {
    if let separator = currentSeparator {
      self.text += separator
      currentSeparator = nil
    }
    self.text += text
  }
}
