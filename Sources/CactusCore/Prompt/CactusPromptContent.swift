import Foundation

// MARK: - CactusPromptContent

/// A composable prompt payload that can contain text and image references.
///
/// Use this type to build structured prompt input before converting it into
/// chat message components.
///
/// ```swift
/// let imageURL = URL(filePath: "/tmp/reference.png")
/// let content = CactusPromptContent {
///   "Summarize this image in 1 sentence."
///   CactusPromptContent(images: [imageURL])
/// }
/// ```
public struct CactusPromptContent {
  /// Message-ready values derived from prompt content.
  public struct MessageComponents: Hashable, Sendable {
    /// The text portion of a message.
    public var text: String

    /// The image URL portion of a message.
    public var images: [URL]

    /// Creates message components from text and optional image URLs.
    ///
    /// - Parameters:
    ///   - text: The text payload.
    ///   - images: Image URLs to associate with the message.
    public init(text: String, images: [URL] = []) {
      self.text = text
      self.images = images
    }
  }

  private enum Block {
    case text(String)
    case separator(String)
    case images([URL])
    case representable(any CactusPromptRepresentable)
  }

  private var blocks = [Block]()

  /// Creates text-only prompt content.
  ///
  /// - Parameter text: Prompt text.
  public init(text: String) {
    self.blocks.append(.text(text))
  }

  /// Creates image-only prompt content.
  ///
  /// - Parameter images: Image URLs to include in the prompt.
  public init(images: [URL]) {
    self.blocks.append(.images(images))
  }

  /// Creates empty prompt content.
  public init() {}

  /// Wraps another prompt representable value.
  ///
  /// - Parameter content: A representable prompt value.
  public init(_ content: some CactusPromptRepresentable) {
    self.blocks.append(.representable(content))
  }

  /// Creates prompt content from a result-builder closure.
  ///
  /// - Parameter build: A prompt builder closure.
  public init<E: Error>(
    @CactusPromptBuilder build: () throws(E) -> some CactusPromptRepresentable
  ) throws(E) {
    self.blocks.append(.representable(try build()))
  }
}

// MARK: - Join

extension CactusPromptContent {
  /// Returns a new prompt by appending another prompt with a separator.
  ///
  /// - Parameters:
  ///   - other: Prompt content to append.
  ///   - separator: Text inserted between joined text segments.
  /// - Returns: A new joined prompt value.
  public func joined(with other: Self, separator: String = "\n") -> Self {
    var content = self
    content.join(with: other, separator: separator)
    return content
  }

  /// Appends another prompt to this prompt with an optional separator.
  ///
  /// - Parameters:
  ///   - other: Prompt content to append.
  ///   - separator: Text inserted between joined text segments.
  public mutating func join(with other: Self, separator: String = "\n") {
    self.blocks.append(.separator(separator))
    self.blocks.append(contentsOf: other.blocks)
  }
}

// MARK: - Message Components

extension CactusPromptContent {
  /// Converts prompt content into message-ready components.
  ///
  /// Text blocks are merged in order and separated by the most recent separator.
  /// Images are collected in insertion order.
  ///
  /// - Returns: Message components containing text and image URLs.
  public func messageComponents() throws -> MessageComponents {
    var components = MessageComponents(text: "")
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
        let subcomponents = try representable.promptContent.messageComponents()
        components.appendText(subcomponents.text, currentSeparator: &currentSeparator)
        components.images.append(contentsOf: subcomponents.images)
      }
    }
    return components
  }
}

extension CactusPromptContent.MessageComponents {
  fileprivate mutating func appendText(_ text: String, currentSeparator: inout String?) {
    if let separator = currentSeparator {
      self.text += separator
      currentSeparator = nil
    }
    self.text += text
  }
}
