import Foundation

// MARK: - CactusLanguageDetection

/// A speech-language detection output.
public struct CactusLanguageDetection: Hashable, Sendable {
  /// Detected language code.
  public let language: CactusSTTLanguage

  /// Raw language token emitted by the model (for example, "<|en|>").
  public let languageToken: String

  /// Token ID corresponding to `languageToken`.
  public let tokenId: UInt32

  /// Confidence in [0, 1].
  public let confidence: Double

  /// Entropy used to derive confidence.
  public let entropy: Double

  /// Total detection time.
  public let totalDuration: Duration

  /// The amount of RAM used by this operation, in MB.
  public let ramUsageMb: Double

  /// Creates a language detection output.
  ///
  /// - Parameters:
  ///   - language: Detected language code.
  ///   - languageToken: Raw language token emitted by the model.
  ///   - tokenId: Token ID corresponding to `languageToken`.
  ///   - confidence: Confidence in [0, 1].
  ///   - entropy: Entropy used to derive confidence.
  ///   - totalDuration: Total detection time.
  ///   - ramUsageMb: RAM used by this operation in MB.
  public init(
    language: CactusSTTLanguage,
    languageToken: String,
    tokenId: UInt32,
    confidence: Double,
    entropy: Double,
    totalDuration: Duration,
    ramUsageMb: Double
  ) {
    self.language = language
    self.languageToken = languageToken
    self.tokenId = tokenId
    self.confidence = confidence
    self.entropy = entropy
    self.totalDuration = totalDuration
    self.ramUsageMb = ramUsageMb
  }
}
