import Cactus
import CustomDump
import Testing

@Suite
struct `ScopedMemoryLoader tests` {
  @Test
  func `Scopes Memory To Session Instance`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.inMemory("count").scope(.session)) private var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        Run { input in
          self.count += input.count
          return self.count
        }
      }
    }

    let session1 = CactusAgenticSession(MyAgent())
    let session2 = CactusAgenticSession(MyAgent())

    let r1 = try await session1.respond(to: "hello")
    let r2 = try await session2.respond(to: "blob")

    expectNoDifference(r1.output, 5)
    expectNoDifference(r2.output, 4)
  }

  @Test
  func `Stores Session Scoped Memory In Session Store`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.inMemory("count").scope(.session)) private var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        Run { input in
          self.count += input.count
          return self.count
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let response = try await session.respond(to: "hello")

    expectNoDifference(response.output, 5)

    let stored = session.scopedMemory.value(
      at: .inMemory("count").scope(.session),
      as: Int.self
    )
    expectNoDifference(stored, 5)
  }
}
