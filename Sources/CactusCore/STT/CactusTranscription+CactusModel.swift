import Foundation

// MARK: - Options

extension CactusModel.Transcription.Options {
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
      cloudHandoffThreshold: request.cloudHandoffThreshold,
      customVocabulary: request.customVocabulary,
      vocabularyBoost: request.vocabularyBoost
    )
  }
}

// MARK: - Segment

extension CactusTranscription.Segment {
  /// Creates a transcription segment.
  ///
  /// - Parameter segment: A ``CactusModel/Transcription/Segment``.
  public init(segment: CactusModel.Transcription.Segment) {
    self.init(
      startDuration: segment.startDuration,
      endDuration: segment.endDuration,
      transcript: segment.text
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
  public init(id: CactusGenerationID, transcription: CactusModel.Transcription) {
    self.init(
      id: id,
      metrics: CactusGenerationMetrics(transcription: transcription),
      transcript: transcription.response,
      segments: transcription.segments.map(Segment.init(segment:))
    )
  }
}
