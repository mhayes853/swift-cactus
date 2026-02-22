import Foundation

// MARK: - CactusTranscription + LanguageModel

extension CactusTranscription {
  /// Creates a parsed transcription from a language model transcription result.
  ///
  /// - Parameter transcription: The language model transcription containing raw response and metrics.
  public init(transcription: CactusLanguageModel.Transcription) {
    self.init(
      prefillTokens: transcription.prefillTokens,
      decodeTokens: transcription.decodeTokens,
      totalTokens: transcription.totalTokens,
      confidence: transcription.confidence,
      prefillTps: transcription.prefillTps,
      decodeTps: transcription.decodeTps,
      ramUsageMb: transcription.ramUsageMb,
      didHandoffToCloud: transcription.didHandoffToCloud,
      durationToFirstToken: transcription.durationToFirstToken,
      totalDuration: transcription.totalDuration,
      content: Content(response: transcription.response)
    )
  }
}
