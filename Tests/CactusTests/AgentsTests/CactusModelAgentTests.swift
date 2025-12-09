import Cactus
import CustomDump
import IssueReporting
import SnapshotTesting
import Testing

@Suite
struct `CactusModelAgent tests` {
  @Test
  func `Basic Qwen Response`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "qwen3-0.6")

    let session = CactusAgenticSession(
      CactusModelAgent<String, Qwen3Response<String>>(.fromModelURL(url)) {
        "You are a philosopher who can philosophize about things."
      }
    )

    let response = try await session.respond(to: "What is the meaning of life?")
    withExpectedIssue {
      assertSnapshot(of: response, as: .json, record: true)
    }
  }

  @Test
  func `Qwen No Think Response`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "qwen3-0.6")

    let session = CactusAgenticSession(
      CactusModelAgent<CactusPromptContent, Qwen3Response<String>>(.fromModelURL(url)) {
        "You are a philosopher who can philosophize about things."
      }
    )

    let response = try await session.respond(
      to: CactusPromptContent {
        Qwen3ThinkMode.noThink
        "What is the meaning of life?"
      }
    )
    withExpectedIssue {
      assertSnapshot(of: response, as: .json, record: true)
    }
  }
}
