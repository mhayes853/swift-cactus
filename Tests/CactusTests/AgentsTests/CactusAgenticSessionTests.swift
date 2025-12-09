import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgentSession tests` {
  @Test
  func `Basic Response`() async throws {
    let session = CactusAgenticSession(PassthroughAgent())
    let response = try await session.respond(to: "blob")
    expectNoDifference(response, "blob")
  }

  @Test
  func `Is Responding True When Responding`() async throws {
    let session = CactusAgenticSession(NeverAgent())

    expectNoDifference(session.isResponding, false)
    let task = Task { try await session.respond(to: "Blob") }
    await Task.megaYield()
    expectNoDifference(session.isResponding, true)
    task.cancel()
  }

  #if canImport(Observation)
    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `Is Responding Observations`() async throws {
      let session = CactusAgenticSession(PassthroughAgent())

      let isResponding = Lock([Bool]())
      let token = observe {
        isResponding.withLock { $0.append(session.isResponding) }
      }
      _ = try await session.respond(to: "Message")

      isResponding.withLock { expectNoDifference($0, [false, true, false]) }
      token.cancel()
    }
  #endif

  @Suite
  struct `Graph tests` {
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
        ["CactusAgenticSessionGraphRoot", someAgent, "CactusModelAgent (qwen3-0.6)"]
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
              EmptyAgent<String, String>().tag("blob")
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
            AnyAgent(
              SomeAgent()
                .transformEnvironment(\.self) { $0[MyKey.self] = true }
            )
          } else {
            AnyAgent(EmptyAgent())
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
          "_EitherAgent",
          "AnyAgent",
          "_TransformEnvironmentAgent",
          someAgent,
          "_EitherAgent",
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
          .pipeOutput(to: EmptyAgent<String, String>())
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
          "CactusModelAgent (qwen3-0.6)",
          "EmptyAgent"
        ]
      )
    }
  }
}

private let someAgent = "CactusTests.`CactusAgentSession tests`.`Graph tests`.SomeAgent"
