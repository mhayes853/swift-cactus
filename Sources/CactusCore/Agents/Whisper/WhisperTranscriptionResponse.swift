import Foundation

public struct WhisperTranscriptionResponse: Hashable, Sendable, ConvertibleFromCactusResponse,
  Identifiable
{
  public struct Timestamp: Hashable, Sendable {
    public let seconds: TimeInterval
    public let transcript: String

    public init(seconds: TimeInterval, transcript: String) {
      self.seconds = seconds
      self.transcript = transcript
    }
  }

  public enum Content: Hashable, Sendable {
    case fullTranscript(String)
    case timestamps([Timestamp])
  }

  public let id: CactusGenerationID
  public let content: Content

  public init(cactusResponse: CactusResponse) {
    self.id = cactusResponse.id

    let fullTranscript = cactusResponse.content.replacingOccurrences(
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
            guard let seconds = TimeInterval(matchGroups[i]) else { return nil }
            let transcript = String(matchGroups[i + 1])
            return Timestamp(seconds: seconds, transcript: transcript)
          }
      )
    }
  }

  public init(id: CactusGenerationID, content: Content) {
    self.id = id
    self.content = content
  }
}

private let responseRegex = try! RegularExpression(
  "<\\|(\\d+(?:\\.\\d+)?)\\|>([\\s\\S]*?)(?=(?:<\\|\\d+(?:\\.\\d+)?\\|>)|$)"
)
