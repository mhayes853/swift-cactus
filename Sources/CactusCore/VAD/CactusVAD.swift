import Foundation

// MARK: - CactusVAD

/// A voice activity detection output.
public struct CactusVAD: Hashable, Sendable {
  /// A detected speech segment.
  public struct Segment: Hashable, Sendable {
    /// Segment start sample index.
    public let startSampleIndex: Int

    /// Segment end sample index.
    public let endSampleIndex: Int

    /// Segment start duration.
    public let startDuration: Duration

    /// Segment end duration.
    public let endDuration: Duration

    /// Segment duration.
    public var duration: Duration {
      self.endDuration - self.startDuration
    }

    /// Creates a segment from sample positions.
    ///
    /// - Parameters:
    ///   - startSampleIndex: Segment start sample index.
    ///   - endSampleIndex: Segment end sample index.
    ///   - samplingRate: Sampling rate in Hz used to convert sample indices to durations.
    public init(
      startSampleIndex: Int,
      endSampleIndex: Int,
      samplingRate: Int
    ) {
      precondition(samplingRate > 0, "Sampling rate must be > 0")
      precondition(
        startSampleIndex >= 0 && endSampleIndex >= 0,
        "Sample indices must be non-negative"
      )
      precondition(endSampleIndex >= startSampleIndex, "endSampleIndex must be >= startSampleIndex")

      self.startSampleIndex = startSampleIndex
      self.endSampleIndex = endSampleIndex
      self.startDuration = .seconds(Double(startSampleIndex) / Double(samplingRate))
      self.endDuration = .seconds(Double(endSampleIndex) / Double(samplingRate))
    }

    /// Creates a segment from sample positions using the default cactus sample rate.
    ///
    /// - Parameters:
    ///   - startSampleIndex: Segment start sample index.
    ///   - endSampleIndex: Segment end sample index.
    public init(startSampleIndex: Int, endSampleIndex: Int) {
      self.init(
        startSampleIndex: startSampleIndex,
        endSampleIndex: endSampleIndex,
        samplingRate: cactusAudioSampleRateHz
      )
    }
  }

  /// The detected speech segments.
  public let segments: [Segment]

  /// The current process RAM usage in MB.
  public let ramUsageMb: Double

  /// The total processing duration.
  public let totalDuration: Duration

  /// Sampling rate in Hz used to interpret segment sample-index timestamps.
  public let samplingRate: Int

  /// The total processing time in seconds.
  public var totalTime: TimeInterval {
    self.totalDuration.secondsDouble
  }

  /// Creates a voice activity detection output.
  ///
  /// - Parameters:
  ///   - segments: The detected speech segments.
  ///   - ramUsageMb: The current process RAM usage in MB.
  ///   - totalDuration: The total processing duration.
  ///   - samplingRate: Sampling rate in Hz used to interpret sample-index timestamps.
  public init(
    segments: [Segment],
    ramUsageMb: Double,
    totalDuration: Duration,
    samplingRate: Int
  ) {
    self.segments = segments
    self.ramUsageMb = ramUsageMb
    self.totalDuration = totalDuration
    self.samplingRate = samplingRate
  }

  /// Creates a voice activity detection output using the default cactus sample rate.
  ///
  /// - Parameters:
  ///   - segments: The detected speech segments.
  ///   - ramUsageMb: The current process RAM usage in MB.
  ///   - totalDuration: The total processing duration.
  public init(
    segments: [Segment],
    ramUsageMb: Double,
    totalDuration: Duration
  ) {
    self.init(
      segments: segments,
      ramUsageMb: ramUsageMb,
      totalDuration: totalDuration,
      samplingRate: cactusAudioSampleRateHz
    )
  }
}
