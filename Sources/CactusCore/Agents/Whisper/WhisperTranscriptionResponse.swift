import Foundation

public enum WhisperTranscriptionResponse: Hashable, Sendable, ConvertibleFromCactusResponse {
  public struct Timestamp: Hashable, Sendable {
    public let seconds: TimeInterval
    public let transcript: String

    public init(seconds: TimeInterval, transcript: String) {
      self.seconds = seconds
      self.transcript = transcript
    }
  }

  case fullTranscript(String)
  case timestamps([Timestamp])

  public init(cactusResponse: String) {
    let fullTranscript = cactusResponse.replacingOccurrences(of: "<|startoftranscript|>", with: "")
    let matchGroups = responseRegex.matchGroups(from: fullTranscript)

    if matchGroups.isEmpty {
      self = .fullTranscript(fullTranscript)
    } else {
      self = .timestamps(
        stride(from: 0, to: matchGroups.count, by: 2)
          .compactMap { i in
            guard let seconds = TimeInterval(matchGroups[i]) else { return nil }
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
