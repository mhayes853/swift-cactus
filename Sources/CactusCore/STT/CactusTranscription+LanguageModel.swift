import Foundation

// MARK: - Options

extension CactusLanguageModel.Transcription.Options {
  /// Creates transcription options from a transcription request.
  ///
  /// - Parameter request: The ``CactusTranscription/Request``.
  public init(request: CactusTranscription.Request) {
    self.init(
      maxTokens: request.maxTokens,
      temperature: request.temperature,
      topP: request.topP,
      topK: request.topK,
      isTelemetryEnabled: request.isTelemetryEnabled,
      useVad: request.useVad,
      cloudHandoffThreshold: request.cloudHandoffThreshold
    )
  }
}

// MARK: - Transcription

extension CactusTranscription {
  /// Creates a parsed transcription from a language model transcription result.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - transcription: The language model transcription containing raw response and metrics.
  public init(id: CactusGenerationID, transcription: CactusLanguageModel.Transcription) {
    self.init(
      id: id,
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
