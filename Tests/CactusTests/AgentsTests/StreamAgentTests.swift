import Cactus
import CustomDump
import Testing

@Suite
struct `StreamAgent tests` {
  @Test
  func `Runs Stream Function`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Stream { request, _ in .finalOutput(request.input) }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let response = try await session.respond(to: "blob")
    expectNoDifference(response.output, "blob")
  }

  @Test
  func `Runs Stream Function With Streaming`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Stream { request, continuation in
          let messageId = CactusMessageID()
          for char in request.input {
            continuation.yield(
              token: CactusStreamedToken(messageStreamId: messageId, stringValue: String(char))
            )
          }
          return .collectTokensIntoOutput()
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let response = try await session.respond(to: "blob")
    expectNoDifference(response.output, "blob")
  }
}
