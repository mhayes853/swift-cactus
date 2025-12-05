import Foundation

// MARK: - CactusPromptEncodedContent

extension CactusPromptRepresentable {
  public func encoded<Encoder: SendableMetatype>(
    with encoder: Encoder
  ) -> _EncodedContent<Self, Encoder> {
    _EncodedContent(content: self, encoder: encoder)
  }
}

public struct _EncodedContent<
  Content: CactusPromptRepresentable,
  Encoder: TopLevelEncoder<Data> & SendableMetatype
>: CactusPromptRepresentable {
  let content: Content
  let encoder: Encoder

  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Content.PromptContentFailure) -> CactusPromptContent {
    var environment = environment
    environment.promptContentEncoder = self.encoder
    return try self.content.promptContent(in: environment)
  }
}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var promptContentEncoder: any TopLevelEncoder<Data> {
    get { self[PromptContentEncoderKey.self].encoder }
    set { self[PromptContentEncoderKey.self] = PromptContentEncoder(encoder: newValue) }
  }

  private enum PromptContentEncoderKey: Key {
    static var defaultValue: PromptContentEncoder {
      PromptContentEncoder(encoder: JSONEncoder())
    }
  }
}

private struct PromptContentEncoder {
  let encoder: any TopLevelEncoder<Data>
}
