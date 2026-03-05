import Foundation

// MARK: - Options

extension CactusModel.LanguageDetectionOptions {
  /// Creates language-detection options from a language-detection request.
  ///
  /// - Parameter request: The ``CactusLanguageDetection/Request``.
  public init(request: CactusLanguageDetection.Request) {
    self.init(
      useVad: request.useVad,
      isTelemetryEnabled: request.isTelemetryEnabled
    )
  }
}

// MARK: - Language Detection

extension CactusLanguageDetection {
  /// Creates a language detection output from a ``CactusModel/LanguageDetection``.
  ///
  /// - Parameter detection: The ``CactusModel/LanguageDetection``.
  public init(detection: CactusModel.LanguageDetection) {
    self.init(
      language: CactusSTTLanguage(rawValue: detection.language),
      languageToken: detection.languageToken,
      tokenId: detection.tokenId,
      confidence: detection.confidence,
      entropy: detection.entropy,
      totalDuration: detection.totalDuration,
      ramUsageMb: detection.ramUsageMb
    )
  }
}
