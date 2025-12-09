import Foundation

// MARK: - CactusPromptEncodedContent

extension CactusPromptRepresentable {
  public func encoded<Encoder>(with encoder: Encoder) -> _EncodedContent<Self, Encoder> {
    _EncodedContent(content: self, encoder: encoder)
  }
}

public struct _EncodedContent<
  Content: CactusPromptRepresentable,
  Encoder: TopLevelEncoder<Data> & Sendable
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
  public var promptContentEncoder: any TopLevelEncoder<Data> & Sendable {
    get { self[PromptContentEncoderKey.self].encoder }
    set { self[PromptContentEncoderKey.self] = PromptContentEncoder(encoder: newValue) }
  }

  private enum PromptContentEncoderKey: Key {
    static var defaultValue: PromptContentEncoder {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        PromptContentEncoder(encoder: JSONEncoder())
      } else {
        PromptContentEncoder(encoder: SendableTopLevelJSONEncoder(JSONEncoder()))
      }
    }
  }
}

private struct PromptContentEncoder {
  let encoder: any TopLevelEncoder<Data> & Sendable
}
