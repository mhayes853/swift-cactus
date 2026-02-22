import Foundation

// MARK: - VADOptions

extension CactusLanguageModel.VADOptions {
  /// Creates VAD options from a ``CactusVAD/Request``.
  ///
  /// - Parameter request: The VAD request that carries option values.
  public init(request: CactusVAD.Request) {
    self.init(
      threshold: request.threshold,
      negThreshold: request.negThreshold,
      minSpeechDuration: request.minSpeechDuration,
      maxSpeechDuration: request.maxSpeechDuration,
      minSilenceDuration: request.minSilenceDuration,
      speechPadDuration: request.speechPadDuration,
      windowSizeSamples: request.windowSizeSamples,
      minSilenceAtMaxSpeech: request.minSilenceAtMaxSpeech,
      useMaxPossSilAtMaxSpeech: request.useMaxPossSilAtMaxSpeech,
      samplingRate: request.samplingRate
    )
  }
}

// MARK: - VADResult

extension CactusVAD {
  /// Creates a VAD output from a language-model VAD result.
  ///
  /// - Parameters:
  ///   - rawResult: The language-model VAD result.
  ///   - samplingRate: Sampling rate in Hz used to interpret frame timestamps.
  public init(rawResult: CactusLanguageModel.VADResult, samplingRate: Int? = nil) {
    self.init(
      segments: rawResult.segments.map {
        CactusVAD.Segment(
          startFrame: $0.startFrame,
          endFrame: $0.endFrame,
          samplingRate: samplingRate ?? cactusAudioSampleRateHz
        )
      },
      ramUsageMb: rawResult.ramUsageMb,
      totalDuration: rawResult.totalDuration,
      samplingRate: samplingRate ?? cactusAudioSampleRateHz
    )
  }
}
