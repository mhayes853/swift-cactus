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

  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Content.PromptContentFailure) -> CactusPromptContent {
    let encoder = self.encoder
    var env = environment
    env[CactusEnvironmentValues.PromptContentEncoderKey.self] = PromptContentEncoder(encoder())
    return try self.content.promptContent(in: env)
  }
}

extension _EncodedContent: Sendable where Encoder: Sendable, Content: Sendable {}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var promptContentEncoder: any TopLevelEncoder<Data> {
    self[PromptContentEncoderKey.self].encoder()
  }

  fileprivate enum PromptContentEncoderKey: Key {
    static let defaultValue = PromptContentEncoder(JSONEncoder())
  }
}

private struct PromptContentEncoder: Sendable {
  @TaskLocal static var current = Self(JSONEncoder())

  let encoder: @Sendable () -> sending any TopLevelEncoder<Data>

  init(_ encoder: @escaping @autoclosure @Sendable () -> sending any TopLevelEncoder<Data>) {
    self.encoder = encoder
  }

  func encode(_ value: JSONValue) throws -> Data {
    try self.encoder().encode(value)
  }
}
