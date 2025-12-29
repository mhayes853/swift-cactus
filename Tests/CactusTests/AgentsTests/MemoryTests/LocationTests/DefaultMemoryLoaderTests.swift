import Cactus
import CustomDump
import Testing

@Suite
struct `DefaultMemoryLoader tests` {
  @Test
  func `Uses Default Value When Not Set`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.testDefault) private var count

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
        Run { self.count }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let r1 = try await session.respond()

    expectNoDifference(r1.output, defaultValue)
  }
}

extension CactusMemoryLocation where Self == InMemoryLocation<Int>.Default {
  fileprivate static var testDefault: Self {
    .withDefault(.inMemory("testDefault"), defaultValue)
  }
}

private let defaultValue = 10
