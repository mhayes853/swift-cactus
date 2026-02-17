// MARK: - CactusStreamedToken

/// A single streamed token emitted during inference.
public struct CactusStreamedToken: Hashable, Sendable {
  /// The message identifier this token belongs to.
  public let messageStreamId: CactusMessageID

  /// The textual value of the streamed token.
  public let stringValue: String

  /// The token identifier from the tokenizer.
  public let tokenId: UInt32

  /// Creates a streamed token.
  ///
  /// - Parameters:
  ///   - messageStreamId: The message identifier for this token.
  ///   - stringValue: The token text.
  ///   - tokenId: The token identifier from the tokenizer.
  public init(messageStreamId: CactusMessageID, stringValue: String, tokenId: UInt32) {
    self.messageStreamId = messageStreamId
    self.stringValue = stringValue
    self.tokenId = tokenId
  }
}
