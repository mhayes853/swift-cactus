import Foundation

// MARK: - Request

extension CactusLanguageDetection {
  /// Input used to perform a language detection request.
  public struct Request: Hashable, Sendable {
    /// The audio content to analyze.
    public let content: Content

    /// Whether to run voice activity detection before language detection.
    public var useVad: Bool?

    /// Whether telemetry is enabled.
    public var isTelemetryEnabled: Bool?

    /// The maximum response buffer size for the underlying language detection call.
    public var maxBufferSize: Int?

    /// Creates a language detection request.
    ///
    /// - Parameters:
    ///   - content: The audio content to analyze.
    ///   - useVad: Whether to run voice activity detection before language detection.
    ///   - isTelemetryEnabled: Whether telemetry is enabled.
    ///   - maxBufferSize: The maximum response buffer size.
    public init(
      content: Content,
      useVad: Bool? = nil,
      isTelemetryEnabled: Bool? = nil,
      maxBufferSize: Int? = nil
    ) {
      self.content = content
      self.useVad = useVad
      self.isTelemetryEnabled = isTelemetryEnabled
      self.maxBufferSize = maxBufferSize
    }
  }
}

// MARK: - Content

extension CactusLanguageDetection.Request {
  /// The audio payload for a language detection request.
  public struct Content: Hashable, Sendable {
    /// The audio file URL to analyze, when file-based input is used.
    public let audioURL: URL?

    /// Raw PCM bytes to analyze, when in-memory PCM input is used.
    ///
    /// Expected format is 16 kHz mono signed 16-bit PCM bytes.
    public let pcmBytes: [UInt8]?

    private init(audioURL: URL?, pcmBytes: [UInt8]?) {
      self.audioURL = audioURL
      self.pcmBytes = pcmBytes
    }

    /// Creates content from an audio file URL.
    ///
    /// - Parameter url: The local audio file URL.
    /// - Returns: Content configured for file-based language detection.
    public static func audio(_ url: URL) -> Self {
      Self(audioURL: url, pcmBytes: nil)
    }

    /// Creates content from raw PCM bytes.
    ///
    /// - Parameter bytes: PCM bytes expected by the language detection engine in 16 kHz mono
    ///   signed 16-bit format.
    /// - Returns: Content configured for PCM-based language detection.
    public static func pcm(_ bytes: [UInt8]) -> Self {
      Self(audioURL: nil, pcmBytes: bytes)
    }
  }
}
