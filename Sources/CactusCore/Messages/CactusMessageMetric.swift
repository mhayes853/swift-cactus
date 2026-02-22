import Foundation

// MARK: - CactusMessageMetric

/// Inference metrics captured for a single model message.
public struct CactusMessageMetric: Hashable, Sendable, Codable {
  /// The number of prefilled tokens.
  public var prefillTokens: Int

  /// The number of tokens decoded.
  public var decodeTokens: Int

  /// The total amount of tokens that make up the response.
  public var totalTokens: Int

  /// The model's confidence in its response.
  public var confidence: Double

  /// The prefill tokens per second.
  public var prefillTps: Double

  /// The decode tokens per second.
  public var decodeTps: Double

  /// The current process RAM usage in MB.
  public var ramUsageMb: Double

  /// The amount of time in seconds to generate the first token.
  public var timeIntervalToFirstToken: TimeInterval

  /// The total generation time in seconds.
  public var totalTimeInterval: TimeInterval

  /// Creates a metrics value.
  ///
  /// - Parameters:
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - decodeTokens: The number of decoded tokens.
  ///   - totalTokens: The total number of tokens.
  ///   - confidence: The confidence score.
  ///   - prefillTps: The prefill tokens-per-second rate.
  ///   - decodeTps: The decode tokens-per-second rate.
  ///   - ramUsageMb: The RAM usage in MB.
  ///   - timeIntervalToFirstToken: The time to first token in seconds.
  ///   - totalTimeInterval: The total generation time in seconds.
  public init(
    prefillTokens: Int = 0,
    decodeTokens: Int = 0,
    totalTokens: Int = 0,
    confidence: Double = 0,
    prefillTps: Double = 0,
    decodeTps: Double = 0,
    ramUsageMb: Double = 0,
    timeIntervalToFirstToken: TimeInterval = 0,
    totalTimeInterval: TimeInterval = 0
  ) {
    self.prefillTokens = prefillTokens
    self.decodeTokens = decodeTokens
    self.totalTokens = totalTokens
    self.confidence = confidence
    self.prefillTps = prefillTps
    self.decodeTps = decodeTps
    self.ramUsageMb = ramUsageMb
    self.timeIntervalToFirstToken = timeIntervalToFirstToken
    self.totalTimeInterval = totalTimeInterval
  }
}

extension CactusMessageMetric {
  /// Creates metrics from a chat completion.
  ///
  /// - Parameter completion: The completion whose metrics should be copied.
  public init(completion: CactusLanguageModel.ChatCompletion) {
    self.init(
      prefillTokens: completion.prefillTokens,
      decodeTokens: completion.decodeTokens,
      totalTokens: completion.totalTokens,
      confidence: completion.confidence,
      prefillTps: completion.prefillTps,
      decodeTps: completion.decodeTps,
      ramUsageMb: completion.ramUsageMb,
      timeIntervalToFirstToken: completion.timeIntervalToFirstToken,
      totalTimeInterval: completion.totalTimeInterval
    )
  }
}

extension CactusMessageMetric {
  /// Creates metrics from a transcription.
  ///
  /// - Parameter transcription: The transcription whose metrics should be copied.
  public init(transcription: CactusLanguageModel.Transcription) {
    self.init(
      prefillTokens: transcription.prefillTokens,
      decodeTokens: transcription.decodeTokens,
      totalTokens: transcription.totalTokens,
      confidence: transcription.confidence,
      prefillTps: transcription.prefillTps,
      decodeTps: transcription.decodeTps,
      ramUsageMb: transcription.ramUsageMb,
      timeIntervalToFirstToken: transcription.timeIntervalToFirstToken,
      totalTimeInterval: transcription.totalTimeInterval
    )
  }

  /// Creates metrics from a parsed transcription.
  ///
  /// - Parameter transcription: The parsed transcription whose metrics should be copied.
  public init(transcription: CactusTranscription) {
    self.init(
      prefillTokens: transcription.prefillTokens,
      decodeTokens: transcription.decodeTokens,
      totalTokens: transcription.totalTokens,
      confidence: transcription.confidence,
      prefillTps: transcription.prefillTps,
      decodeTps: transcription.decodeTps,
      ramUsageMb: transcription.ramUsageMb,
      timeIntervalToFirstToken: transcription.durationToFirstToken.secondsDouble,
      totalTimeInterval: transcription.totalDuration.secondsDouble
    )
  }
}
