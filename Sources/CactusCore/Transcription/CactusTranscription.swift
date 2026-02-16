import Foundation

// MARK: - CactusTranscription

/// A parsed transcription output.
///
/// This type parses raw transcription text into either a full transcript string
/// or timestamped segments when timestamp tags are present.
public struct CactusTranscription: Hashable, Sendable {
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
  }

  /// The parsed transcription content.
  public let content: Content

  /// Creates a parsed transcription from a raw model response string.
  ///
  /// This removes `<|startoftranscript|>` markers and parses timestamp groups
  /// matching the `<|seconds|>text` format.
  ///
  /// - Parameter rawResponse: The raw transcription response string.
  public init(rawResponse: String) {
    let fullTranscript = rawResponse.replacingOccurrences(
      of: "<|startoftranscript|>",
      with: ""
    )
    let matchGroups = responseRegex.matchGroups(from: fullTranscript)

    if matchGroups.isEmpty {
      self.content = .fullTranscript(fullTranscript)
    } else {
      self.content = .timestamps(
        stride(from: 0, to: matchGroups.count, by: 2)
          .compactMap { i in
            guard i + 1 < matchGroups.count,
              let seconds = TimeInterval(matchGroups[i])
            else {
              return nil
            }
            let transcript = String(matchGroups[i + 1])
            return Timestamp(seconds: seconds, transcript: transcript)
          }
      )
    }
  }
}

private let responseRegex = try! RegularExpression(
  "<\\|(\\d+(?:\\.\\d+)?)\\|>([\\s\\S]*?)(?=(?:<\\|\\d+(?:\\.\\d+)?\\|>)|$)"
)
