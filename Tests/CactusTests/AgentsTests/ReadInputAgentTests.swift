import Cactus
import CustomDump
import Testing

@Suite
struct `ReadInputAgent tests` {
  @Test
  func `Calls Agent Based On Input`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        ReadInput { input in
          if input.isEmpty {
            Run { _ in "Empty" }
          } else {
            Run { _ in "Non-empty" }
          }
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let r1 = try await session.respond(to: "")
    let r2 = try await session.respond(to: "non-empty")

    expectNoDifference(r1.output, "Empty")
    expectNoDifference(r2.output, "Non-empty")
  }
}
