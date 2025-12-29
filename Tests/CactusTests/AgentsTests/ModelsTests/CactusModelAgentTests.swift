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
      CactusModelAgent<String, Qwen3Completion<String>>(
        .url(url),
        transcript: .constant(CactusTranscript())
      ) {
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
      CactusModelAgent<CactusPromptContent, Qwen3Completion<String>>(
        .url(url),
        transcript: .constant(CactusTranscript())
      ) {
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

    let transcriptState = Lock(CactusTranscript())
    let binding = MemoryBinding<CactusTranscript>(
      get: { transcriptState.withLock { $0 } },
      set: { newValue in transcriptState.withLock { $0 = newValue } }
    )

    let session = CactusAgenticSession(
      CactusModelAgent<String, String>(.url(url), transcript: binding) {
        systemPrompt
      }
    )

    let user1 = "What is the meaning of the universe?"
    let response1 = try await session.respond(to: user1)

    let user2 = "What are the pros and cons of abstraction?"
    let response2 = try await session.respond(to: user2)

    let transcript = transcriptState.withLock { $0 }

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

  @Test
  func `System Prompt Is Written To Transcript`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let transcriptState = Lock(
      CactusTranscript(
        elements: CollectionOfOne(
          CactusTranscript.Element(id: CactusMessageID(), message: .system("Old prompt"))
        )
      )
    )
    let binding = MemoryBinding<CactusTranscript>(
      get: { transcriptState.withLock { $0 } },
      set: { newValue in transcriptState.withLock { $0 = newValue } }
    )

    let session = CactusAgenticSession(
      CactusModelAgent<String, String>(.url(url), transcript: binding) {
        "New prompt"
      }
    )

    _ = try await session.respond(to: "Hello")

    let transcript = transcriptState.withLock { $0 }
    expectNoDifference(transcript.first?.message, .system("New prompt"))
  }

  @Test
  func `Constant Transcript Binding Does Not Persist`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let transcript = CactusTranscript(
      elements: CollectionOfOne(
        CactusTranscript.Element(id: CactusMessageID(), message: .system("Start"))
      )
    )
    let binding = MemoryBinding<CactusTranscript>.constant(transcript)

    let session = CactusAgenticSession(
      CactusModelAgent<String, String>(.url(url), transcript: binding) {
        "Replacement prompt"
      }
    )

    _ = try await session.respond(to: "Hello")
    _ = try await session.respond(to: "What about now?")

    expectNoDifference(binding.wrappedValue, transcript)
  }
}
