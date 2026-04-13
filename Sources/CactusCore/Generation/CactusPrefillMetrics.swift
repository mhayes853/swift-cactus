import Foundation

// MARK: - CactusPrefillMetrics

/// Metrics captured during a model prefill run.
public struct CactusPrefillMetrics: Hashable, Sendable {
  /// The number of prefilled tokens.
  public var prefillTokens: Int

  /// The prefill tokens-per-second throughput.
  public var prefillTps: Double

  /// The total prefill duration.
  public var totalDuration: Duration

  /// The process RAM usage in MB.
  public var ramUsageMb: Double

  /// Creates prefill metrics.
  ///
  /// - Parameters:
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - prefillTps: The prefill tokens-per-second throughput.
  ///   - totalDuration: The total prefill duration.
  ///   - ramUsageMb: The process RAM usage in MB.
  public init(
    prefillTokens: Int,
    prefillTps: Double,
    totalDuration: Duration,
    ramUsageMb: Double
  ) {
    self.prefillTokens = prefillTokens
    self.prefillTps = prefillTps
    self.totalDuration = totalDuration
    self.ramUsageMb = ramUsageMb
  }

  /// Creates prefill metrics from a model prefill result.
  ///
  /// - Parameter prefillResult: The prefill result containing metrics.
  public init(prefillResult: CactusModel.PrefillResult) {
    self.init(
      prefillTokens: prefillResult.prefillTokens,
      prefillTps: prefillResult.prefillTps,
      totalDuration: prefillResult.totalDuration,
      ramUsageMb: prefillResult.ramUsageMb
    )
  }
}
