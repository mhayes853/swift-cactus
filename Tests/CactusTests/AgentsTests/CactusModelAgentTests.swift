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
      CactusModelAgent<String, Qwen3Completion<String>>(.fromModelURL(url)) {
        "You are a philosopher who can philosophize about things."
      }
    )

    let response = try await session.respond(to: "What is the meaning of life?")
    withExpectedIssue {
      assertSnapshot(of: response, as: .dump, record: true)
    }
  }

  @Test
  func `Qwen No Think Response`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "qwen3-0.6")

    let session = CactusAgenticSession(
      CactusModelAgent<CactusPromptContent, Qwen3Completion<String>>(.fromModelURL(url)) {
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
      assertSnapshot(of: response, as: .dump, record: true)
    }
  }

  @Test
  func `Stores Transcript Between Responses`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")

    let systemPrompt = "You are a philosopher who can philosophize about things."

    let key: CactusTranscript.Key = "blob"
    let store = InMemoryTranscriptStore()

    let session = CactusAgenticSession(
      CactusModelAgent<String, String>(.fromModelURL(url), transcriptKey: key) {
        systemPrompt
      }
      .transcriptStore(store)
    )

    let user1 = "What is the meaning of the universe?"
    let response1 = try await session.respond(to: user1)

    let user2 = "What are the pros and cons of abstraction?"
    let response2 = try await session.respond(to: user2)

    let transcript = try #require(try await store.transcript(forKey: key))

    expectNoDifference(
      transcript.map(\.message),
      [
        .system(systemPrompt),
        .user(user1),
        .assistant(response1.output),
        .user(user2),
        .assistant(response2.output)
      ]
    )
  }
}
