import Foundation

// MARK: - CactusAgentInferenceMetrics

public typealias CactusAgentInferenceMetrics = [CactusMessageID: CactusAgentInferenceMetric]

// MARK: - CactusAgentInferenceMetric

public struct CactusAgentInferenceMetric: Hashable, Sendable, Codable {
  /// The tokens per second rate.
  public var tokensPerSecond: Double

  /// The number of prefilled tokens.
  public var prefillTokens: Int

  /// The number of tokens decoded.
  public var decodeTokens: Int

  /// The total amount of tokens that make up the response.
  public var totalTokens: Int

  /// The amount of time in seconds to generate the first token.
  public var timeIntervalToFirstToken: TimeInterval

  /// The total generation time in seconds.
  public var totalTimeInterval: TimeInterval

  public init(
    tokensPerSecond: Double,
    prefillTokens: Int,
    decodeTokens: Int,
    totalTokens: Int,
    timeIntervalToFirstToken: TimeInterval,
    totalTimeInterval: TimeInterval
  ) {
    self.tokensPerSecond = tokensPerSecond
    self.prefillTokens = prefillTokens
    self.decodeTokens = decodeTokens
    self.totalTokens = totalTokens
    self.timeIntervalToFirstToken = timeIntervalToFirstToken
    self.totalTimeInterval = totalTimeInterval
  }
}

extension CactusAgentInferenceMetric {
  public init(transcription: CactusLanguageModel.Transcription) {
    self.init(
      tokensPerSecond: transcription.tokensPerSecond,
      prefillTokens: transcription.prefillTokens,
      decodeTokens: transcription.decodeTokens,
      totalTokens: transcription.totalTokens,
      timeIntervalToFirstToken: transcription.timeIntervalToFirstToken,
      totalTimeInterval: transcription.totalTimeInterval
    )
  }
}

extension CactusAgentInferenceMetric {
  public init(completion: CactusLanguageModel.ChatCompletion) {
    self.init(
      tokensPerSecond: completion.tokensPerSecond,
      prefillTokens: completion.prefillTokens,
      decodeTokens: completion.decodeTokens,
      totalTokens: completion.totalTokens,
      timeIntervalToFirstToken: completion.timeIntervalToFirstToken,
      totalTimeInterval: completion.totalTimeInterval
    )
  }
}
