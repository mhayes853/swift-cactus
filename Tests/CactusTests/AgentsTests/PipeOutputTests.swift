import Cactus
import CustomDump
import Testing

@Suite
struct `PipeOutput tests` {
  @Test
  func `Pipes Output Through Piped Agent`() async throws {
    let session = CactusAgenticSession(
      Run<String, Int> { input in input.count }
        .pipeOutput(to: Run { count in "Count: \(count)" })
    )

    let response = try await session.respond(to: "Hello, world")

    expectNoDifference(response.output, "Count: 12")
  }
}
