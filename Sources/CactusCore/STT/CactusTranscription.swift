import Foundation

// MARK: - CactusTranscription

/// A transcription output with metrics from an transcription model.
public struct CactusTranscription: Hashable, Sendable, Identifiable {
  /// The unique identifier for this transcription.
  public let id: CactusGenerationID

  /// The number of prefilled tokens.
  public let prefillTokens: Int

  /// The number of tokens decoded.
  public let decodeTokens: Int

  /// The total amount of tokens that make up the response.
  public let totalTokens: Int

  /// The model's confidence in its response.
  public let confidence: Double

  /// The prefill tokens per second.
  public let prefillTps: Double

  /// The decode tokens per second.
  public let decodeTps: Double

  /// The current process RAM usage in MB.
  public let ramUsageMb: Double

  /// Whether this transcription was handed off to cloud inference.
  public let didHandoffToCloud: Bool

  /// The amount of time to generate the first token.
  public let durationToFirstToken: Duration

  /// The total generation time.
  public let totalDuration: Duration

  /// The parsed transcription content.
  public let content: Content

  /// Creates a parsed transcription with explicit content and metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - decodeTokens: The number of tokens decoded.
  ///   - totalTokens: The total amount of tokens.
  ///   - confidence: The model's confidence in its response.
  ///   - prefillTps: The prefill tokens per second.
  ///   - decodeTps: The decode tokens per second.
  ///   - ramUsageMb: The current process RAM usage in MB.
  ///   - didHandoffToCloud: Whether this transcription was handed off to cloud inference.
  ///   - durationToFirstToken: The amount of time to generate the first token.
  ///   - totalDuration: The total generation time.
  ///   - content: The parsed transcription content.
  public init(
    id: CactusGenerationID,
    prefillTokens: Int,
    decodeTokens: Int,
    totalTokens: Int,
    confidence: Double,
    prefillTps: Double,
    decodeTps: Double,
    ramUsageMb: Double,
    didHandoffToCloud: Bool,
    durationToFirstToken: Duration,
    totalDuration: Duration,
    content: Content
  ) {
    self.id = id
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
    self.content = content
  }

  /// Creates a parsed transcription from a raw model response string with explicit metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - response: The raw transcription response string.
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - decodeTokens: The number of tokens decoded.
  ///   - totalTokens: The total amount of tokens.
  ///   - confidence: The model's confidence in its response.
  ///   - prefillTps: The prefill tokens per second.
  ///   - decodeTps: The decode tokens per second.
  ///   - ramUsageMb: The current process RAM usage in MB.
  ///   - didHandoffToCloud: Whether this transcription was handed off to cloud inference.
  ///   - durationToFirstToken: The amount of time to generate the first token.
  ///   - totalDuration: The total generation time.
  public init(
    id: CactusGenerationID,
    response: String,
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
    self.id = id
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
    self.content = Content(response: response)
  }

  /// A single timestamped transcription segment.
  public struct Timestamp: Hashable, Sendable {
    /// The start time in seconds for this segment.
    public let seconds: TimeInterval

    /// The transcript text associated with this timestamp.
    public let transcript: String

    /// Creates a timestamped segment.
    ///
    /// - Parameters:
    ///   - seconds: The segment start time in seconds.
    ///   - transcript: The segment transcript text.
    public init(seconds: TimeInterval, transcript: String) {
      self.seconds = seconds
      self.transcript = transcript
    }
  }

  /// The parsed transcription content.
  public enum Content: Hashable, Sendable {
    /// A full transcript without timestamp segmentation.
    case fullTranscript(String)

    /// A transcript split into timestamped segments.
    case timestamps([Timestamp])

    /// Creates parsed content from a raw model response string.
    ///
    /// - Parameter response: The raw transcription response string.
    public init(response: String) {
      let matchGroups = responseRegex.matchGroups(from: response)

      if matchGroups.isEmpty {
        self = .fullTranscript(response)
      } else {
        self = .timestamps(
          stride(from: 0, to: matchGroups.count, by: 2)
            .compactMap { i in
              guard i + 1 < matchGroups.count,
                let seconds = TimeInterval(matchGroups[i])
              else {
                return nil
              }
              var transcript = String(matchGroups[i + 1])
              if transcript.first == " " {
                transcript.removeFirst()
              }
              return Timestamp(seconds: seconds, transcript: transcript)
            }
        )
      }
    }

    /// The raw response string reconstructed from the content.
    public var response: String {
      switch self {
      case .fullTranscript(let transcript):
        return transcript
      case .timestamps(let timestamps):
        return
          timestamps.map { timestamp in
            let secondsString = String(format: "%.2f", timestamp.seconds)
            return "<|\(secondsString)|>\(timestamp.transcript)"
          }
          .joined()
      }
    }
  }
}

private let responseRegex = try! RegularExpression(
  "<\\|(\\d+(?:\\.\\d+)?)\\|>([\\s\\S]*?)(?=(?:<\\|\\d+(?:\\.\\d+)?\\|>)|$)"
)
