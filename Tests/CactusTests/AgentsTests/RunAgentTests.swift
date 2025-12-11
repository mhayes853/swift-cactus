import Cactus
import CustomDump
import Testing

@Suite
struct `RunAgent tests` {
  @Test
  func `Runs The Closure`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Run { $0 }
      }
    }

    let session = CactusAgenticSession(MyAgent())

    let response = try await session.respond(to: "blob")
    expectNoDifference(response.output, "blob")
  }
}
