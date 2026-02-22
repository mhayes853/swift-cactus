import Foundation

// MARK: - Request

extension CactusVAD {
  /// Input used to perform a voice activity detection request.
  public struct Request: Hashable, Sendable {
    /// The audio content to analyze.
    public let content: Content

    /// The detection threshold.
    public var threshold: Float?

    /// The negative detection threshold.
    public var negThreshold: Float?

    /// The minimum speech duration to keep.
    public var minSpeechDuration: CactusDuration?

    /// The maximum speech duration to keep.
    public var maxSpeechDuration: CactusDuration?

    /// The minimum silence duration required between speech segments.
    public var minSilenceDuration: CactusDuration?

    /// The amount of padding duration to add around speech segments.
    public var speechPadDuration: CactusDuration?

    /// The VAD window size in samples.
    public var windowSizeSamples: Int?

    /// Minimum silence at max speech in milliseconds.
    public var minSilenceAtMaxSpeech: Int?

    /// Whether to use max possible silence at max speech.
    public var useMaxPossSilAtMaxSpeech: Bool?

    /// Sampling rate in Hz.
    public var samplingRate: Int?

    /// The maximum response buffer size for the underlying VAD call.
    public var maxBufferSize: Int?

    /// Creates a voice activity detection request.
    ///
    /// - Parameters:
    ///   - content: The audio content to analyze.
    ///   - threshold: The detection threshold.
    ///   - negThreshold: The negative detection threshold.
    ///   - minSpeechDuration: The minimum speech duration to keep.
    ///   - maxSpeechDuration: The maximum speech duration to keep.
    ///   - minSilenceDuration: The minimum silence duration between segments.
    ///   - speechPadDuration: The padding duration added around speech segments.
    ///   - windowSizeSamples: The VAD window size in samples.
    ///   - minSilenceAtMaxSpeech: Minimum silence at max speech in milliseconds.
    ///   - useMaxPossSilAtMaxSpeech: Whether to use max possible silence at max speech.
    ///   - samplingRate: Sampling rate in Hz.
    ///   - maxBufferSize: The maximum response buffer size.
    public init(
      content: Content,
      threshold: Float? = nil,
      negThreshold: Float? = nil,
      minSpeechDuration: CactusDuration? = nil,
      maxSpeechDuration: CactusDuration? = nil,
      minSilenceDuration: CactusDuration? = nil,
      speechPadDuration: CactusDuration? = nil,
      windowSizeSamples: Int? = nil,
      minSilenceAtMaxSpeech: Int? = nil,
      useMaxPossSilAtMaxSpeech: Bool? = nil,
      samplingRate: Int? = nil,
      maxBufferSize: Int? = nil
    ) {
      self.content = content
      self.threshold = threshold
      self.negThreshold = negThreshold
      self.minSpeechDuration = minSpeechDuration
      self.maxSpeechDuration = maxSpeechDuration
      self.minSilenceDuration = minSilenceDuration
      self.speechPadDuration = speechPadDuration
      self.windowSizeSamples = windowSizeSamples
      self.minSilenceAtMaxSpeech = minSilenceAtMaxSpeech
      self.useMaxPossSilAtMaxSpeech = useMaxPossSilAtMaxSpeech
      self.samplingRate = samplingRate
      self.maxBufferSize = maxBufferSize
    }
  }
}

// MARK: - Content

extension CactusVAD.Request {
  /// The audio payload for a voice activity detection request.
  ///
  /// Construct instances with ``audio(_:)`` or ``pcm(_:)``.
  public struct Content: Hashable, Sendable {
    /// The audio file URL to analyze, when file-based input is used.
    public let audioURL: URL?

    /// Raw PCM bytes to analyze, when in-memory PCM input is used.
    public let pcmBytes: [UInt8]?

    private init(audioURL: URL?, pcmBytes: [UInt8]?) {
      self.audioURL = audioURL
      self.pcmBytes = pcmBytes
    }

    /// Creates content from an audio file URL.
    ///
    /// - Parameter url: The local audio file URL.
    /// - Returns: Content configured for file-based VAD.
    public static func audio(_ url: URL) -> Self {
      Self(audioURL: url, pcmBytes: nil)
    }

    /// Creates content from raw PCM bytes.
    ///
    /// - Parameter bytes: PCM bytes expected by the VAD engine.
    /// - Returns: Content configured for PCM-based VAD.
    public static func pcm(_ bytes: [UInt8]) -> Self {
      Self(audioURL: nil, pcmBytes: bytes)
    }
  }
}
