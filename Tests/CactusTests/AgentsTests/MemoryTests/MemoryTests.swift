import Cactus
import CustomDump
import IssueReporting
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
  func `Memory Is Shared Across Sessions By Default`() async throws {
    struct MyAgent: CactusAgent {
      @Memory("__count__") var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        Run { input in
          self.count += input.count
          return self.count
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let session2 = CactusAgenticSession(MyAgent())

    let r1 = try await session.respond(to: "blob")
    let r2 = try await session2.respond(to: "throb")

    expectNoDifference(r1.output, 4)
    expectNoDifference(r2.output, 9)
  }

  @Test
  func `Multiple Memory Instances Are Independent`() async throws {
    struct MyAgent: CactusAgent {
      @Memory("a") var messageA = ""
      @Memory("b") var messageB = ""

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

  @Test
  func `Memory Inside ReadInput`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        ReadInput { _ in
          CounterAgent()
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let r1 = try await session.respond(to: "blob")
    let r2 = try await session.respond(to: "throb")

    expectNoDifference(r1.output, 4)
    expectNoDifference(r2.output, 9)
  }

  @Test
  func `Memory Inside Imperative Stream`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
        Stream { request, continuation in
          try await CounterAgent().stream(request: request, into: continuation)
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let r1 = try await session.respond(to: "blob")
    let r2 = try await session.respond(to: "throb")

    expectNoDifference(r1.output, 4)
    expectNoDifference(r2.output, 9)
  }

  @Test
  func `Reports Issue When Memory Location Fails To Load Value`() async throws {
    struct FailToLoad: CactusMemoryLocation {
      func key(in environment: CactusEnvironmentValues) -> String {
        "failToLoad"
      }

      func value(
        in environment: CactusEnvironmentValues,
        currentValue: String
      ) async throws -> String {
        struct SomeError: Error {}
        throw SomeError()
      }

      func save(value: String, in environment: CactusEnvironmentValues) async throws {
      }
    }

    struct MyAgent: CactusAgent {
      @Memory(FailToLoad().scopedToSession) var value = "blob"

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, String> {
        Run { _ in self.value }
      }
    }

    let session = CactusAgenticSession(MyAgent())

    var output = ""
    await withExpectedIssue {
      let r = try await session.respond()
      output = r.output
    }
    expectNoDifference(output, "blob")
  }

  @Test
  func `Reports Issue When Memory Location Fails To Save Value`() async throws {
    struct FailToSave: CactusMemoryLocation {
      func key(in environment: CactusEnvironmentValues) -> String {
        "failToSave"
      }

      func value(
        in environment: CactusEnvironmentValues,
        currentValue: String
      ) async throws -> String {
        currentValue
      }

      func save(value: String, in environment: CactusEnvironmentValues) async throws {
        struct SomeError: Error {}
        throw SomeError()
      }
    }

    struct MyAgent: CactusAgent {
      @Memory(FailToSave().scopedToSession) var value = "blob"

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Run { input in
          self.value = input
          return self.value
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())

    var output = ""
    await withExpectedIssue {
      let r = try await session.respond(to: "updated")
      await Task.megaYield()
      output = r.output
    }
    expectNoDifference(output, "updated")
  }

  @Test
  func `Uses Proper Load Reason`() async throws {
    struct TestLocation: CactusMemoryLocation {
      func key(in environment: CactusEnvironmentValues) -> String {
        "testLocation"
      }

      func value(
        in environment: CactusEnvironmentValues,
        currentValue: String
      ) async throws -> String {
        if environment.memoryLoadReason == .hydration {
          "hydrated"
        } else {
          "refreshed"
        }
      }

      func save(value: Value, in environment: CactusEnvironmentValues) async throws {
      }
    }

    struct MyAgent: CactusAgent {
      @Memory(TestLocation().scopedToSession) var value = ""

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, [String]> {
        Run { input in
          var values = [self.value]
          try await self.$value.refresh(in: environment)
          values.append(self.value)
          return values
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond()

    expectNoDifference(resp.output, ["hydrated", "refreshed"])
  }

  @Test
  func `Flushes Current Value Into Location`() async throws {
    final class TestLocation: CactusMemoryLocation {
      func key(in environment: CactusEnvironmentValues) -> String {
        "Flush Time"
      }

      let flushed = Lock("")

      func value(
        in environment: CactusEnvironmentValues,
        currentValue: String
      ) async throws -> String {
        currentValue
      }

      func save(value: String, in environment: CactusEnvironmentValues) async throws {
        self.flushed.withLock { $0 = value }
      }
    }

    struct MyAgent: CactusAgent {
      @Memory var value: String
      private let location: TestLocation

      init(location: TestLocation) {
        self._value = Memory(wrappedValue: "", location.scopedToSession)
        self.location = location
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Run { input in
          self.value = input
          self.location.flushed.withLock { $0 = "" }
          try await self.$value.flush(in: environment)
          return self.location.flushed.withLock { $0 }
        }
      }
    }

    let session = CactusAgenticSession(MyAgent(location: TestLocation()))
    let resp = try await session.respond(to: "blob")

    expectNoDifference(resp.output, "blob")
  }
}

private struct CounterAgent: CactusAgent {
  @Memory(.inMemory("count").scopedToSession) var count = 0

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, Int> {
    Run { input in
      self.count += input.count
      return self.count
    }
  }
}
