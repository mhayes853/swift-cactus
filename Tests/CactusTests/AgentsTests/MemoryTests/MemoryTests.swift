import Cactus
import CustomDump
import Testing

@Suite
struct `Memory tests` {
  @Test
  func `Memory Is Stable Across Different Messages`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        CounterAgent()
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let r1 = try await session.respond(to: "blob")
    let r2 = try await session.respond(to: "throb")

    expectNoDifference(r1.output, 4)
    expectNoDifference(r2.output, 9)
  }

  @Test
  func `Memory Is Scoped To Session Instance By Default`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        CounterAgent()
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let session2 = CactusAgenticSession(MyAgent())

    let r1 = try await session.respond(to: "blob")
    let r2 = try await session2.respond(to: "throb")

    expectNoDifference(r1.output, 4)
    expectNoDifference(r2.output, 5)
  }

  @Test
  func `Multiple Memory Instances Are Independent`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var messageA = ""
      @Memory var messageB = ""

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Run { input in
          if self.messageA.isEmpty {
            self.messageA = input
            return self.messageA
          }
          self.messageB = input
          return self.messageB
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())

    let r1 = try await session.respond(to: "blob")
    let r2 = try await session.respond(to: "throb")

    expectNoDifference(r1.output, "blob")
    expectNoDifference(r2.output, "throb")
  }
}

private struct CounterAgent: CactusAgent {
  @Memory var count = 0

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
    Run { input in
      self.count += input.count
      return self.count
    }
  }
}
