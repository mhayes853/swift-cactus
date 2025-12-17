import Cactus
import CustomDump
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
