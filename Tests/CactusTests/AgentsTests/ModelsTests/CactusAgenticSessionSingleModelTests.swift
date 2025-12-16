import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgenticSessionSingleModel tests` {
  @Test
  func `Default Transcript Is Session Scoped`() async throws {
    let systemPrompt = "You are a helpful assistant."
    let url = try await CactusLanguageModel.testModelURL(slug: "gemma3-270m")
    let session = CactusAgenticSession<String, String>(.url(url)) {
      systemPrompt
    }

    _ = try await session.respond(to: "Hello world")

    let sessionTranscript = session.scopedMemory.value(
      at: .inMemory(_defaultAgenticSessionTranscriptKey).scope(.session),
      as: CactusTranscript.self
    )
    expectNoDifference(sessionTranscript?.first?.message, .system(systemPrompt))
  }
}
