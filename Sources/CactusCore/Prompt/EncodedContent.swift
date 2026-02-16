import Foundation

// MARK: - Encoded Content

extension CactusPromptRepresentable {
  /// Overrides the encoder used for nested encodable prompt values.
  ///
  /// ```swift
  /// struct Payload: Codable, CactusPromptRepresentable {
  ///   let id: Int
  ///   let name: String
  /// }
  ///
  /// let encoder = JSONEncoder()
  /// encoder.outputFormatting = [.sortedKeys]
  ///
  /// let content = CactusPromptContent {
  ///   Payload(id: 1, name: "Blob")
  ///     .encoded(with: encoder)
  /// }
  /// ```
  ///
  /// - Parameter encoder: The top-level encoder to apply.
  /// - Returns: A prompt wrapper that applies the encoder to its subtree.
  public func encoded<Encoder>(with encoder: Encoder) -> _EncodedContent<Self, Encoder>
  where Encoder: TopLevelEncoder<Data> {
    _EncodedContent(content: self, encoder: encoder)
  }
}

/// A prompt wrapper that applies a custom top-level encoder to nested prompt values.
public struct _EncodedContent<
  Content: CactusPromptRepresentable,
  Encoder: TopLevelEncoder<Data>
>: CactusPromptRepresentable {
  let content: Content
  let encoder: Encoder

  public var promptContent: CactusPromptContent {
    get throws {
      let components = try _CactusPromptContext.$encoder.withValue(AnyTopLevelEncoder(self.encoder)) {
        try self.content.promptContent.messageComponents()
      }

      var content = CactusPromptContent(text: components.text)
      if !components.images.isEmpty {
        content.join(with: CactusPromptContent(images: components.images), separator: "")
      }
      return content
    }
  }
}

// MARK: - Default Codable Prompt Encoding

extension CactusPromptRepresentable where Self: Encodable {
  public var promptContent: CactusPromptContent {
    get throws {
      let data = try _CactusPromptContext.encoder.encode(self)
      return CactusPromptContent(text: String(decoding: data, as: UTF8.self))
    }
  }
}
