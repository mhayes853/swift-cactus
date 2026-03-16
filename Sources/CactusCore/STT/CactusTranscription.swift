import Foundation

// MARK: - CactusTranscription

/// A transcription output with metrics from a transcription model.
public struct CactusTranscription: Hashable, Sendable, Identifiable {
  /// The unique identifier for this transcription.
  public let id: CactusGenerationID

  /// Generation metrics for this transcription.
  public let metrics: CactusGenerationMetrics

  /// The full transcript text.
  public let transcript: String

  /// Structured timed segments for the transcript.
  public let segments: [Segment]

  /// Creates a parsed transcription with explicit transcript, segments, and metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - metrics: Generation metrics for this transcription.
  ///   - transcript: The full transcript text.
  ///   - segments: Structured timed segments for the transcript.
  public init(
    id: CactusGenerationID,
    metrics: CactusGenerationMetrics,
    transcript: String,
    segments: [Segment]
  ) {
    self.id = id
    self.metrics = metrics
    self.transcript = transcript
    self.segments = segments
  }

  /// Creates a parsed transcription with explicit content and metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - metrics: Generation metrics for this transcription.
  ///   - content: The parsed transcription content.
  @available(*, deprecated, message: "Use init(id:metrics:transcript:segments:) instead.")
  public init(
    id: CactusGenerationID,
    metrics: CactusGenerationMetrics,
    content: Content
  ) {
    self.id = id
    self.metrics = metrics
    switch content {
    case .fullTranscript(let transcript):
      self.transcript = transcript
      self.segments = [Segment]()
    case .timestamps(let timestamps):
      self.transcript = timestamps.map(\.transcript).joined(separator: " ")
      self.segments = timestamps.map(Segment.init(timestamp:))
    }
  }

  /// Creates a parsed transcription from a raw model response string with explicit metrics.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this transcription.
  ///   - metrics: Generation metrics for this transcription.
  ///   - response: The raw transcription response string.
  @available(*, deprecated, message: "Use init(id:metrics:transcript:segments:) instead.")
  public init(
    id: CactusGenerationID,
    metrics: CactusGenerationMetrics,
    response: String
  ) {
    self.init(id: id, metrics: metrics, content: Content(response: response))
  }

  /// A single timestamped transcription segment.
  public struct Segment: Hashable, Sendable {
    /// The start time for this segment.
    public let startDuration: Duration

    /// The end time for this segment.
    public let endDuration: Duration

    /// The transcript text associated with this segment.
    public let transcript: String

    /// Creates a timestamped segment.
    ///
    /// - Parameters:
    ///   - startDuration: The segment start time.
    ///   - endDuration: The segment end time.
    ///   - transcript: The segment transcript text.
    public init(startDuration: Duration, endDuration: Duration, transcript: String) {
      self.startDuration = startDuration
      self.endDuration = endDuration
      self.transcript = transcript
    }

    @available(*, deprecated)
    fileprivate init(timestamp: Timestamp) {
      self.init(
        startDuration: timestamp.startDuration,
        endDuration: timestamp.startDuration,
        transcript: timestamp.transcript
      )
    }
  }

  /// A legacy timestamp-only transcription segment.
  @available(*, deprecated, message: "Use CactusTranscription.Segment instead.")
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

  /// A deprecated parsed transcription view.
  @available(*, deprecated, message: "Use transcript and segments directly.")
  public enum Content: Hashable, Sendable {
    /// A full transcript without timestamp segmentation.
    case fullTranscript(String)

    /// A transcript split into legacy timestamp-only segments.
    case timestamps([Timestamp])

    /// Creates parsed content from a raw model response string.
    ///
    /// - Parameter response: The raw transcription response string.
    public init(response: String) {
      let matchGroups = response.matches(of: responseRegex)
        .flatMap { match in
          let output = match.output
          return [output.1, output.2]
        }

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
        transcript
      case .timestamps(let timestamps):
        timestamps.map { timestamp in
          let secondsString = String(format: "%.2f", timestamp.startDuration.secondsDouble)
          return "<|\(secondsString)|>\(timestamp.transcript)"
        }
        .joined()
      }
    }
  }

  /// A deprecated parsed transcription view.
  @available(*, deprecated, message: "Use transcript and segments directly.")
  public var content: Content {
    if self.segments.isEmpty {
      .fullTranscript(self.transcript)
    } else {
      .timestamps(
        self.segments.map {
          Timestamp(startDuration: $0.startDuration, transcript: $0.transcript)
        }
      )
    }
  }
}

private nonisolated(unsafe) let responseRegex =
  #/<\|(\d+(?:\.\d+)?)\|>([\s\S]*?)(?=(?:<|\d+(?:\.\d+)?|>)|$)/#
