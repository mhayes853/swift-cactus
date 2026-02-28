import Foundation

// MARK: - CactusTranscription

/// A transcription output with metrics from an transcription model.
public struct CactusTranscription: Hashable, Sendable, Identifiable {
  /// The unique identifier for this transcription.
  public let id: CactusGenerationID

  /// Generation metrics for this transcription.
  public let metrics: CactusGenerationMetrics

  /// The parsed transcription content.
  public let content: Content

  /// Creates a parsed transcription with explicit content and metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - metrics: Generation metrics for this transcription.
  ///   - content: The parsed transcription content.
  public init(
    id: CactusGenerationID,
    metrics: CactusGenerationMetrics,
    content: Content
  ) {
    self.id = id
    self.metrics = metrics
    self.content = content
  }

  /// Creates a parsed transcription from a raw model response string with explicit metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - metrics: Generation metrics for this transcription.
  ///   - response: The raw transcription response string.
  public init(
    id: CactusGenerationID,
    metrics: CactusGenerationMetrics,
    response: String
  ) {
    self.id = id
    self.metrics = metrics
    self.content = Content(response: response)
  }

  /// A single timestamped transcription segment.
  public struct Timestamp: Hashable, Sendable {
    /// The start time for this segment.
    public let startDuration: Duration

    /// The transcript text associated with this timestamp.
    public let transcript: String

    /// Creates a timestamped segment.
    ///
    /// - Parameters:
    ///   - startDuration: The segment start time.
    ///   - transcript: The segment transcript text.
    public init(startDuration: Duration, transcript: String) {
      self.startDuration = startDuration
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
                let secondsDouble = Double(matchGroups[i])
              else {
                return nil
              }
              let seconds = Duration.seconds(secondsDouble)
              var transcript = String(matchGroups[i + 1])
              if transcript.first == " " {
                transcript.removeFirst()
              }
              return Timestamp(startDuration: seconds, transcript: transcript)
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
            let secondsString = String(format: "%.2f", timestamp.startDuration.secondsDouble)
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
