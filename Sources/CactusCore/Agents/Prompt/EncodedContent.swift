import Foundation

// MARK: - CactusPromptEncodedContent

extension CactusPromptRepresentable {
  public func encoded<Encoder: SendableMetatype>(
    with encoder: @escaping @autoclosure @Sendable () -> Encoder
  ) -> _EncodedContent<Self, Encoder> {
    _EncodedContent(content: self, encoder: encoder)
  }
}

public struct _EncodedContent<
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

extension _EncodedContent: Sendable where Encoder: Sendable, Content: Sendable {}

// MARK: - PromptContentEncoder

struct PromptContentEncoder: Sendable {
  @TaskLocal static var current = Self(JSONEncoder())

  private let encoder: @Sendable () -> sending any TopLevelEncoder<Data>

  init(_ encoder: @escaping @autoclosure @Sendable () -> sending any TopLevelEncoder<Data>) {
    self.encoder = encoder
  }

  func encode(_ value: JSONValue) throws -> Data {
    try self.encoder().encode(value)
  }
}
