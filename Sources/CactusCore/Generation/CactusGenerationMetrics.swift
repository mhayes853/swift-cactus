import Foundation

// MARK: - CactusGenerationMetrics

/// Generation metrics captured during a model generation run.
public struct CactusGenerationMetrics: Hashable, Sendable {
  /// The number of prefilled tokens.
  public var prefillTokens: Int

  /// The number of decoded tokens.
  public var decodeTokens: Int

  /// The total number of tokens.
  public var totalTokens: Int

  /// The model's confidence in its response.
  public var confidence: Double

  /// The prefill tokens-per-second throughput.
  public var prefillTps: Double

  /// The decode tokens-per-second throughput.
  public var decodeTps: Double

  /// The process RAM usage in MB.
  public var ramUsageMb: Double

  /// Whether the generation was handed off to cloud inference.
  public var didHandoffToCloud: Bool

  /// The time to first token.
  public var durationToFirstToken: Duration

  /// The total generation duration.
  public var totalDuration: Duration

  /// Creates generation metrics.
  ///
  /// - Parameters:
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - decodeTokens: The number of decoded tokens.
  ///   - totalTokens: The total number of tokens.
  ///   - confidence: The model's confidence in its response.
  ///   - prefillTps: The prefill tokens-per-second throughput.
  ///   - decodeTps: The decode tokens-per-second throughput.
  ///   - ramUsageMb: The process RAM usage in MB.
  ///   - didHandoffToCloud: Whether the generation was handed off to cloud inference.
  ///   - durationToFirstToken: The time to first token.
  ///   - totalDuration: The total generation duration.
  public init(
    prefillTokens: Int,
    decodeTokens: Int,
    totalTokens: Int,
    confidence: Double,
    prefillTps: Double,
    decodeTps: Double,
    ramUsageMb: Double,
    didHandoffToCloud: Bool,
    durationToFirstToken: Duration,
    totalDuration: Duration
  ) {
    self.prefillTokens = prefillTokens
    self.decodeTokens = decodeTokens
    self.totalTokens = totalTokens
    self.confidence = confidence
    self.prefillTps = prefillTps
    self.decodeTps = decodeTps
    self.ramUsageMb = ramUsageMb
    self.didHandoffToCloud = didHandoffToCloud
    self.durationToFirstToken = durationToFirstToken
    self.totalDuration = totalDuration
  }

  /// Creates generation metrics from a model completion.
  ///
  /// - Parameter completion: The completion response containing generation metrics.
  public init(completion: CactusModel.Completion) {
    self.init(
      prefillTokens: completion.prefillTokens,
      decodeTokens: completion.decodeTokens,
      totalTokens: completion.totalTokens,
      confidence: completion.confidence,
      prefillTps: completion.prefillTps,
      decodeTps: completion.decodeTps,
      ramUsageMb: completion.ramUsageMb,
      didHandoffToCloud: completion.didHandoffToCloud,
      durationToFirstToken: completion.durationToFirstToken,
      totalDuration: completion.totalDuration
    )
  }

  /// Creates generation metrics from a model transcription.
  ///
  /// - Parameter transcription: The transcription response containing generation metrics.
  public init(transcription: CactusModel.Transcription) {
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
      totalDuration: transcription.totalDuration
    )
  }
}
