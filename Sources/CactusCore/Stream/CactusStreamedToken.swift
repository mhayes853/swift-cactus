// MARK: - CactusStreamedToken

/// A single streamed token emitted during inference.
public struct CactusStreamedToken: Hashable, Sendable {
  /// The generation identifier this token belongs to.
  public let generationStreamId: CactusGenerationID

  /// The textual value of the streamed token.
  public let stringValue: String

  /// The token identifier from the tokenizer.
  public let tokenId: UInt32

  /// Creates a streamed token.
  ///
  /// - Parameters:
  ///   - generationStreamId: The generation identifier for this token.
  ///   - stringValue: The token text.
  ///   - tokenId: The token identifier from the tokenizer.
  public init(generationStreamId: CactusGenerationID, stringValue: String, tokenId: UInt32) {
    self.generationStreamId = generationStreamId
    self.stringValue = stringValue
    self.tokenId = tokenId
  }
}
