import Cactus
import CustomDump
import IssueReporting
import SnapshotTesting
import Testing

@Suite
struct `WhisperTranscribeAgent tests` {
  @Test
  func `Transcribes Audio Without Timestamp`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")

    let session = CactusAgenticSession(WhisperTranscribeAgent(.url(modelURL)))
    let response = try await session.respond(
      to: WhisperTranscribePrompt(language: .greek, includeTimestamps: false, audioURL: .testAudio)
    )

    withExpectedIssue {
      assertSnapshot(of: response, as: .dump, record: true)
    }
  }

  @Test
  func `Transcribes Audio With Timestamp`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")

    let session = CactusAgenticSession(WhisperTranscribeAgent(.url(modelURL)))
    let response = try await session.respond(
      to: WhisperTranscribePrompt(
        language: .english,
        includeTimestamps: true,
        audioURL: .testAudio
      )
    )

    withExpectedIssue {
      assertSnapshot(of: response, as: .dump, record: true)
    }
  }
}
