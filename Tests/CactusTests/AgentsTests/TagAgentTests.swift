import Cactus
import CustomDump
import IssueReporting
import Testing

@Suite
struct `TagAgent tests` {
  @Test
  func `Tagged Agent Pipes Output Into Another Agent`() async throws {
    let session = CactusAgenticSession(
      Run<String, String> { "Tagged: \($0)" }
        .tag("tagged")
        .pipeOutput(to: Run { "Piped: \($0)" })
    )

    let stream = session.stream(for: "Hello")
    let taggedStream = try await stream.substream(as: String.self, for: "tagged")

    async let finalResponse = stream.collectResponse()
    async let taggedResponse = taggedStream.collectResponse()

    let (final, tagged) = try await (finalResponse, taggedResponse)
    expectNoDifference(tagged.output, "Tagged: Hello")
    expectNoDifference(final.output, "Piped: Tagged: Hello")
  }

  @Test
  func `Missing Tag Throws When Collecting Substream`() async throws {
    let session = CactusAgenticSession(PassthroughAgent())

    let stream = session.stream(for: "Hello")

    await #expect(throws: CactusAgentStreamError.missingSubstream(for: "missing")) {
      try await stream.substream(as: String.self, for: "missing")
    }
  }

  @Test
  func `Nested Tagged Agent Accessible From Root Stream`() async throws {
    let session = CactusAgenticSession(ParentPassthroughTaggedAgent().tag("parent"))

    let stream = session.stream(for: "Hello")
    let childStream = try await stream.substream(as: String.self, for: "child")

    async let finalResponse = stream.collectResponse()
    async let childResponse = childStream.collectResponse()

    let (final, child) = try await (finalResponse, childResponse)
    expectNoDifference(final.output, "Hello")
    expectNoDifference(child.output, "Hello")
  }

  @Test
  func `Substream Can Be Retrieved After Parent Finishes`() async throws {
    let session = CactusAgenticSession(
      Run<String, String> { "Tagged: \($0)" }
        .tag("tagged")
        .pipeOutput(to: Run { "Piped: \($0)" })
    )

    let stream = session.stream(for: "Hello")
    let parentResponse = try await stream.collectResponse()

    let taggedStream = try await stream.substream(as: String.self, for: "tagged")
    let taggedResponse = try await taggedStream.collectResponse()

    expectNoDifference(taggedResponse.output, "Tagged: Hello")
    expectNoDifference(parentResponse.output, "Piped: Tagged: Hello")
  }

  @Test
  func `Missing Substream Requested After Parent Completes Throws`() async throws {
    let session = CactusAgenticSession(PassthroughAgent())

    let stream = session.stream(for: "Hello")
    _ = try await stream.collectResponse()

    await #expect(throws: CactusAgentStreamError.missingSubstream(for: "missing")) {
      _ = try await stream.substream(as: String.self, for: "missing")
    }
  }

  @Test
  func `Incorrect Substream Type While Parent Running Throws`() async throws {
    let session = CactusAgenticSession(
      Run<String, String> { "Tagged: \($0)" }
        .tag("tagged")
        .pipeOutput(to: Run { "Piped: \($0)" })
    )

    let stream = session.stream(for: "Hello")

    await #expect(throws: CactusAgentStreamError.invalidSubstreamType(Int.self)) {
      _ = try await stream.substream(as: Int.self, for: "tagged")
    }
  }

  @Test
  func `Incorrect Substream Type After Parent Completes Throws`() async throws {
    let session = CactusAgenticSession(
      Run<String, String> { "Tagged: \($0)" }
        .tag("tagged")
        .pipeOutput(to: Run { "Piped: \($0)" })
    )

    let stream = session.stream(for: "Hello")
    _ = try await stream.collectResponse()

    await #expect(throws: CactusAgentStreamError.invalidSubstreamType(Int.self)) {
      _ = try await stream.substream(as: Int.self, for: "tagged")
    }
  }

  @Test
  func `Tagged Substream Succeeds When Parent Fails`() async throws {
    let session = CactusAgenticSession(
      Run<String, String> { "Tagged: \($0)" }
        .tag("tagged")
        .pipeOutput(to: Run<String, String> { _ in throw TestError.baseFailure })
    )

    let stream = session.stream(for: "Hello")
    let taggedStream = try await stream.substream(as: String.self, for: "tagged")

    async let taggedResponse = taggedStream.collectResponse()
    await #expect(throws: TestError.baseFailure) {
      _ = try await stream.collectResponse()
    }

    let tagged = try await taggedResponse
    expectNoDifference(tagged.output, "Tagged: Hello")
  }

  @Test
  func `Substream From Manually Appended Stream Inside Stream Agent`() async throws {
    struct MyAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Stream { request, continuation in
          let innerStream = continuation.openSubstream(
            tag: "inner-stream"
          ) { innerContinuation -> CactusAgentStream<String>.Response in
            let runAgent = Run<String, String> { "Manual run: \($0)" }
            let runRequest = CactusAgentRequest(
              input: request.input,
              environment: request.environment
            )
            let runStream = innerContinuation.openSubstream(tag: "manual-run") { runContinuation in
              try await runAgent.stream(request: runRequest, into: runContinuation)
            }
            return try await runStream.streamResponse()
          }

          return try await innerStream.streamResponse().map { "(Final) \($0)" }
        }
      }
    }

    let session = CactusAgenticSession(MyAgent())

    let stream = session.stream(for: "Hello")
    let runStream = try await stream.substream(as: String.self, for: "manual-run")

    let parentResponse = try await stream.collectResponse()
    let runResponse = try await runStream.collectResponse()

    expectNoDifference(parentResponse.output, "(Final) Manual run: Hello")
    expectNoDifference(runResponse.output, "Manual run: Hello")
  }

  @Test
  func `Multiple Untagged Substreams Can Yield Tagged Agents`() async throws {
    struct UntaggedStreamAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        Stream { request, continuation in
          let firstStream = continuation.openSubstream { subContinuation in
            let runAgent = Run<String, String> { "First run: \($0)" }
              .tag("first-run")
            return try await runAgent.stream(request: request, into: subContinuation)
          }

          let secondStream = continuation.openSubstream { subContinuation in
            let runAgent = Run<String, Int> { $0.count }
              .tag("second-run")
            return try await runAgent.stream(request: request, into: subContinuation)
          }

          _ = try await firstStream.streamResponse()
          _ = try await secondStream.streamResponse()
          return .finalOutput("Done")
        }
      }
    }

    let input = "Hello World"
    let session = CactusAgenticSession(UntaggedStreamAgent())

    let stream = session.stream(for: input)
    let firstStream = try await stream.substream(as: String.self, for: "first-run")
    let secondStream = try await stream.substream(as: Int.self, for: "second-run")

    async let firstResponse = firstStream.collectResponse()
    async let secondResponse = secondStream.collectResponse()

    let (first, second) = try await (firstResponse, secondResponse)

    expectNoDifference(first.output, "First run: \(input)")
    expectNoDifference(second.output, input.count)
  }

  @Test
  func `Duplicate Tags Report Issue`() async throws {
    struct DuplicateTaggedAgent: CactusAgent {
      func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
        PassthroughAgent()
          .tag("duplicate")
          .pipeOutput(to: PassthroughAgent().tag("duplicate"))
      }
    }

    let session = CactusAgenticSession(DuplicateTaggedAgent())
    await withExpectedIssue {
      _ = try await session.respond(to: "Hello")
    }
  }

  @Test
  func `Non Existent Doubly Nested Substream Throws`() async throws {
    let session = CactusAgenticSession(
      PassthroughAgent()
        .tag("child")
        .tag("parent")
    )

    let stream = session.stream(for: "Hello")

    await #expect(throws: CactusAgentStreamError.missingSubstream(for: "grandchild")) {
      try await stream.substream(as: String.self, for: "grandchild")
    }
  }
}

private struct ParentPassthroughTaggedAgent: CactusAgent {
  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
    PassthroughAgent().tag("child")
  }
}

private enum TestError: Error {
  case baseFailure
}
