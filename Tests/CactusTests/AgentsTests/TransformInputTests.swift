import Cactus
import CustomDump
import Testing

@Suite
struct `TransformInput tests` {
  struct Payload: Sendable {
    var message: String
    var metadata: Int
  }

  @Test
  func `Transforms Input Before Child Agent`() async throws {
    let session = CactusAgenticSession(
      TransformInput<Payload, PassthroughAgent>(\.message) {
        PassthroughAgent()
      }
    )
    let response = try await session.respond(
      to: Payload(message: "Hello, world!", metadata: 42)
    )

    expectNoDifference(response.output, "Hello, world!")
  }
}
