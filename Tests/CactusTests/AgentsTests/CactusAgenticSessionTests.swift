import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgenticSession Graph tests` {
  @Test
  func `Produces Single Node Graph For Empty Agent`() async {
    let session = CactusAgenticSession(EmptyAgent<String, String>())
    let graph = await session.graph()

    expectNoDifference(graph.count, 1)
    expectNoDifference(graph.root.typeName, "EmptyAgent<String, String>")
  }

  @Test
  func `Produces Multi-Node Graph For Custom Agent`() async {
    struct SomeAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        CactusModelAgent(.fromDirectory(slug: "qwen3-0.6")) {
          "You are an assistant..."
        }
      }
    }

    let session = CactusAgenticSession(SomeAgent())
    let graph = await session.graph()

    expectNoDifference(graph.count, 2)
    expectNoDifference(graph.root.typeName, "SomeAgent")
    expectNoDifference(graph.root.typeName, "CactusModelAgent<String, String>")
  }
}
