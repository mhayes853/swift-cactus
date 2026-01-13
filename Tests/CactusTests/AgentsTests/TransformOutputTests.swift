import Cactus
import CustomDump
import Testing

@Suite
struct `TransformOutput tests` {
  @Test
  func `Transforms Output From Agent`() async throws {
    let session = CactusAgenticSession(PassthroughAgent().transformOutput { $0.count })
    let response = try await session.respond(to: "Hello, world!")

    expectNoDifference(response.output, 13)
  }

  @Test
  func `inputAsOutput Returns Input`() async throws {
    let session = CactusAgenticSession(Run<String, Int> { $0.count }.inputAsOutput())
    let response = try await session.respond(to: "Echo")

    expectNoDifference(response.output, "Echo")
  }

  @Test
  func `Transforms Both Input And Output`() async throws {
    struct Payload: Sendable {
      var message: String
      var metadata: Int
    }

    let session = CactusAgenticSession(
      TransformInput<Payload, PassthroughAgent>(\.message) {
        PassthroughAgent()
      }
      .transformOutput { output, input in "\(output)-\(input.metadata)" }
    )
    let response = try await session.respond(
      to: Payload(message: "Payload", metadata: 7)
    )

    expectNoDifference(response.output, "Payload-7")
  }

  @Test
  func `Transforms Model Output To Character Count`() async throws {
    let url = try await CactusLanguageModel.testModelURL(
      request: CactusLanguageModel.testModelRequest
    )

    let session = CactusAgenticSession(
      CactusModelAgent<String, String>(
        .url(url),
        transcript: .constant(CactusTranscript())
      ) {
        "Respond concisely to the user."
      }
      .transformOutput { $0.count }
    )

    let response = try await session.respond(to: "How many characters will this response contain?")

    expectNoDifference(response.output > 0, true)
  }
}
