// MARK: - CactusPromptEncodedContent

public struct CactusPromptEncodedContent<Encoder: TopLevelEncoder>: CactusPromptRepresentable {
  public let content: JSONValue
  public let encoder: Encoder

  public var promptContent: CactusPromptContent {
    fatalError()
  }

  public init(content: some ConvertibleToJSONValue, encoder: Encoder) {
    self.content = content.jsonValue
    self.encoder = encoder
  }
}

// MARK: - ConvertibleToJSONValue

extension ConvertibleToJSONValue {
  public func encoder<Encoder>(_ encoder: Encoder) -> CactusPromptEncodedContent<Encoder> {
    CactusPromptEncodedContent(content: self, encoder: encoder)
  }
}
