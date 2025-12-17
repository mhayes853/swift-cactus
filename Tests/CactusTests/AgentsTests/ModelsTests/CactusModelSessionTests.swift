import Cactus
import CustomDump
import Testing

@Suite
struct `CactusModelSession tests` {
  @Test
  func `Default Transcript Is Session Scoped`() async throws {
    let systemPrompt = "You are a helpful assistant."
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let session = CactusModelSession<String, String>(.url(url)) {
      systemPrompt
    }

    _ = try await session.respond(to: "Hello world")

    let transcript = try await session.transcript()
    expectNoDifference(transcript.first?.message, .system(systemPrompt))
  }

  @Test
  func `Transcript Loads With No Messages And Default Location`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let session = CactusModelSession<String, String>(.url(url)) {
      "You are a helpful assistant."
    }

    let transcript = try await session.transcript()
    expectNoDifference(transcript.isEmpty, true)
  }

  @Test
  func `Loads Shared Scoped Transcript After Responding`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")

    let systemPrompt = "You are a philosopher who can philosophize about things."
    let userMessage = "What is the meaning of life?"

    let session = CactusModelSession<String, String>(
      .url(url),
      transcript: .inMemory("shared-transcript").scope(.shared)
    ) {
      systemPrompt
    }

    let response = try await session.respond(to: userMessage)
    let transcript = try await session.transcript()

    expectNoDifference(
      transcript.map(\.message),
      [
        .system(systemPrompt),
        .user(userMessage),
        .assistant(response.output)
      ]
    )
  }

  @Test
  func `Loads Transcript From Explicit Location Without Messages`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")

    let session = CactusModelSession<String, String>(
      .url(url),
      transcript: .inMemory("explicit-transcript").scope(.shared)
    ) {
      "You are a helpful assistant."
    }

    let transcript = try await session.transcript()
    expectNoDifference(transcript.isEmpty, true)
  }

  @Test
  func `Force Refresh Reloads Shared Transcript`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")

    let systemPrompt = "You are a helpful assistant."
    let userMessage = "Hello world"

    let session1 = CactusModelSession<String, String>(
      .url(url),
      transcript: .inMemory("shared-force-refresh").scope(.shared)
    ) {
      systemPrompt
    }

    _ = try await session1.respond(to: userMessage)

    let session2 = CactusModelSession<String, String>(
      .url(url),
      transcript: .inMemory("shared-force-refresh").scope(.shared)
    ) {
      systemPrompt
    }

    let refreshedTranscript = try await session2.transcript(forceRefresh: true)
    let originalTranscript = try await session1.transcript()

    expectNoDifference(
      originalTranscript.map(\.message),
      refreshedTranscript.map(\.message)
    )
  }

  @Test
  func `Prewarm Uses Provided ModelStore`() async throws {
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let loader = CountingModelLoader(key: "prewarm", url: url)
    let session = CactusModelSession<String, String>(
      loader,
      transcript: .inMemory("prewarm-model-store").scope(.session)
    )

    let store = SharedModelStore()
    var environment = CactusEnvironmentValues()
    environment.modelStore = store

    try await session.prewarm(in: environment)
    loader.count.withLock { expectNoDifference($0, 1) }

    _ = try await session.respond(to: "Hello world", in: environment)
    loader.count.withLock { expectNoDifference($0, 1) }
  }
}
