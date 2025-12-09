import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgenticSession Graph tests` {
  @Test
  func `Produces Single Node Graph For Empty Agent`() async {
    let session = CactusAgenticSession(EmptyAgent<String, String>())
    let graph = await session.graph()

    expectNoDifference(graph.count, 2)
    expectNoDifference(graph.root.label, "CactusAgenticSessionGraphRoot")
    expectNoDifference(graph.map(\.label), ["CactusAgenticSessionGraphRoot", "EmptyAgent"])
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

    expectNoDifference(graph.count, 3)
    expectNoDifference(
      graph.map(\.label),
      ["CactusAgenticSessionGraphRoot", someAgent, "CactusModelAgent"]
    )
  }

  @Test
  func `Stores Tag For Agent`() async {
    struct SomeAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        CactusModelAgent(.fromDirectory(slug: "qwen3-0.6")) {
          "You are an assistant..."
        }
        .tag("blob")
      }
    }

    let session = CactusAgenticSession(SomeAgent())
    let graph = await session.graph()

    expectNoDifference(graph.count, 4)
    expectNoDifference(graph[tag: "blob"]?.label, "_TagAgent (\"blob\")")
  }

  #if DEBUG
    @Test
    func `Reports Issue When Duplicate Tags In Agent`() async {
      struct SomeAgent: CactusAgent {
        func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
          CactusModelAgent(.fromDirectory(slug: "qwen3-0.6")) {
            "You are an assistant..."
          }
          .tag("blob")
          .pipeOutput {
            return EmptyAgent<String, String>().tag("blob")
          }
        }
      }

      let session = CactusAgenticSession(SomeAgent())
      await withKnownIssue {
        _ = await session.graph()
      } matching: { issue in
        issue.comments.contains(Comment(rawValue: _agentGraphDuplicateTag("blob")))
      }
    }
  #endif

  @Test
  func `Tranforms Environment When Computing Graph`() async {
    enum MyKey: CactusEnvironmentValues.Key, Hashable {
      static let defaultValue = false
    }

    struct SomeAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        if !environment[MyKey.self] {
          return AnyAgent(
            SomeAgent()
              .transformEnvironment(\.self) { $0[MyKey.self] = true }
          )
        } else {
          return AnyAgent(EmptyAgent())
        }
      }
    }

    let session = CactusAgenticSession(SomeAgent())
    let graph = await session.graph()

    expectNoDifference(
      graph.map(\.label),
      [
        "CactusAgenticSessionGraphRoot",
        someAgent,
        "AnyAgent",
        "_TransformEnvironmentAgent",
        someAgent,
        "AnyAgent",
        "EmptyAgent"
      ]
    )
  }

  @Test
  func `Agent With Modifiers`() async {
    struct SomeAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        CactusModelAgent(.fromDirectory(slug: "qwen3-0.6")) {
          "You are an assistant..."
        }
        .tag("blob")
        .pipeOutput {
          return EmptyAgent<String, String>()
        }
        .transformOutput { $0 + $0 }
        .transformInput { $0 + "blob" }
      }
    }

    let session = CactusAgenticSession(SomeAgent())
    let graph = await session.graph()
    expectNoDifference(
      graph.map(\.label),
      [
        "CactusAgenticSessionGraphRoot",
        someAgent,
        "_TransformInputAgent (String -> String)",
        "_TransformOutputAgent (String -> String)",
        "_PipeOutputAgent (String)",
        "_TagAgent (\"blob\")",
        "CactusModelAgent",
        "EmptyAgent"
      ]
    )
  }
}

private let someAgent = "CactusTests.`CactusAgenticSession Graph tests`.SomeAgent"
