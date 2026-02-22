import Foundation

// MARK: - CactusVAD

/// A voice activity detection output.
public struct CactusVAD: Hashable, Sendable {
  /// A detected speech segment.
  public struct Segment: Hashable, Sendable {
    /// Segment start frame.
    public let startFrame: Int

    /// Segment end frame.
    public let endFrame: Int

    /// Segment start duration.
    public let startDuration: CactusDuration

    /// Segment end duration.
    public let endDuration: CactusDuration

    /// Segment duration.
    public var duration: CactusDuration {
      self.endDuration - self.startDuration
    }

    /// Creates a segment from frame positions.
    ///
    /// - Parameters:
    ///   - startFrame: Segment start frame.
    ///   - endFrame: Segment end frame.
    ///   - samplingRate: Sampling rate in Hz used to convert frames to durations.
    public init(
      startFrame: Int,
      endFrame: Int,
      samplingRate: Int
    ) {
      let resolvedSamplingRate = max(samplingRate, 1)
      self.startFrame = startFrame
      self.endFrame = endFrame
      self.startDuration = CactusDuration.seconds(Double(startFrame) / Double(resolvedSamplingRate))
      self.endDuration = CactusDuration.seconds(Double(endFrame) / Double(resolvedSamplingRate))
    }

    /// Creates a segment from frame positions using the default cactus sample rate.
    ///
    /// - Parameters:
    ///   - startFrame: Segment start frame.
    ///   - endFrame: Segment end frame.
    public init(startFrame: Int, endFrame: Int) {
      self.init(startFrame: startFrame, endFrame: endFrame, samplingRate: cactusAudioSampleRateHz)
    }
  }

  /// The detected speech segments.
  public let segments: [Segment]

  /// The current process RAM usage in MB.
  public let ramUsageMb: Double

  /// The total processing duration.
  public let totalDuration: CactusDuration

  /// Sampling rate in Hz used to interpret segment frame timestamps.
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
  ///   - samplingRate: Sampling rate in Hz used to interpret frame timestamps.
  public init(
    segments: [Segment],
    ramUsageMb: Double,
    totalDuration: CactusDuration,
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
    totalDuration: CactusDuration
  ) {
    self.init(
      segments: segments,
      ramUsageMb: ramUsageMb,
      totalDuration: totalDuration,
      samplingRate: cactusAudioSampleRateHz
    )
  }
}
