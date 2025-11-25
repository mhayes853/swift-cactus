import Foundation

// MARK: - CactusPromptRepresentable

extension CactusPromptRepresentable {
  public func encoded<Encoder: SendableMetatype>(
    with encoder: @escaping @autoclosure @Sendable () -> Encoder
  ) -> _CactusPromptEncodedContent<Self, Encoder> {
    _CactusPromptEncodedContent(content: self, encoder: encoder)
  }
}

// MARK: - CactusPromptEncodedContent

public struct _CactusPromptEncodedContent<
  Content: CactusPromptRepresentable,
  Encoder: TopLevelEncoder<Data> & SendableMetatype
>: CactusPromptRepresentable {
  let content: Content
  let encoder: @Sendable () -> Encoder

  public var promptContent: CactusPromptContent {
    get throws {
      let encoder = self.encoder
      return try PromptContentEncoder.$current.withValue(PromptContentEncoder(encoder())) {
        try content.promptContent
      }
    }
  }
}

extension _CactusPromptEncodedContent: Sendable where Encoder: Sendable, Content: Sendable {}
