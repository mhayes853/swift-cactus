import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgentStream tests` {
  @Suite
  struct `Tokens tests` {
    @Test
    func `Tokens AsyncSequence Collects All Tokens`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      var output = ""
      for try await token in stream.tokens {
        output += token.stringValue
      }

      expectNoDifference(output, expectedStreamedOutput)
    }

    @Test
    func `OnToken Callback Collects All Tokens`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")

      let subscription = stream.onToken { token in
        output.withLock { $0 += token.stringValue }
      }

      _ = subscription

      _ = try await stream.streamResponse()

      output.withLock { expectNoDifference($0, expectedStreamedOutput) }
    }

    @Test
    func `OnToken Callback Can Cancel Subscription`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")
      let subscription = Lock<CactusSubscription?>(nil)

      subscription.withLock {
        $0 = stream.onToken { token in
          let count = output.withLock { output in
            output += token.stringValue
            return output.count
          }
          if count >= streamedTokenCount / 2 {
            subscription.withLock { $0?.cancel() }
          }
        }
      }

      _ = try await stream.streamResponse()

      output.withLock { expectNoDifference($0.count < streamedTokenCount, true) }
      _ = subscription
    }

    @Test
    func `Tokens AsyncSequence Task Can Be Cancelled`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")

      let task = Task {
        for try await token in stream.tokens {
          output.withLock { $0 += token.stringValue }
        }
      }

      await Task.megaYield()
      task.cancel()

      await #expect(throws: CancellationError.self) {
        _ = try await task.value
      }

      output.withLock { expectNoDifference($0.count < streamedTokenCount, true) }
    }

    @Test
    func `Tokens AsyncSequence Stops After Stream Stop When Agent Cooperates With Cancellation`()
      async throws
    {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")

      let task = Task {
        for try await token in stream.tokens {
          output.withLock { $0 += token.stringValue }
        }
      }

      await Task.megaYield()
      stream.stop()

      await #expect(throws: CancellationError.self) {
        _ = try await task.value
      }

      output.withLock { expectNoDifference($0.count < streamedTokenCount, true) }
    }

    @Test
    func `OnToken Callback Stops After Stream Stop When Agent Cooperates With Cancellation`()
      async throws
    {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")

      let subscription = stream.onToken { token in
        let count = output.withLock { output in
          output += token.stringValue
          return output.count
        }
        if count >= streamedTokenCount / 2 {
          stream.stop()
        }
      }

      await #expect(throws: CancellationError.self) {
        try await stream.streamResponse()
      }

      _ = subscription

      output.withLock { expectNoDifference($0.count < streamedTokenCount, true) }
    }

    @Test
    func `Tokens AsyncSequence Buffers Tokens Before Consumption`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      _ = try await stream.streamResponse()

      var output = ""
      for try await token in stream.tokens {
        output += token.stringValue
      }

      expectNoDifference(output, expectedStreamedOutput)
    }

    @Test
    func `OnFinished Callback Receives Error When Agent Throws`() async throws {
      let session = CactusAgenticSession(FailingStreamAgent())
      let stream = session.stream()

      let finished = Lock<Result<String, any Error>?>(nil)

      let subscription = stream.onToken(
        perform: { _ in },
        onFinished: { result in
          finished.withLock { $0 = result }
        }
      )

      await #expect(throws: StreamTestError.self) {
        _ = try await stream.streamResponse()
      }

      _ = subscription

      finished.withLock { result in
        _ = #expect(throws: StreamTestError.boom) {
          try result?.get()
        }
      }
    }

    @Test
    func `OnFinished Callback Receives Final Output`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let finished = Lock<Result<String, any Error>?>(nil)

      let subscription = stream.onToken(
        perform: { _ in },
        onFinished: { result in
          finished.withLock { $0 = result }
        }
      )

      _ = try await stream.streamResponse()

      _ = subscription

      try finished.withLock { result in
        let output = try #require(try? result?.get())
        expectNoDifference(output, expectedStreamedOutput)
      }
    }
  }
}

private let streamedTokenCount = 4096
private let expectedStreamedOutput = String(repeating: "a", count: streamedTokenCount)

private enum StreamTestError: Error, Hashable {
  case boom
}

private struct CharacterStreamedAgent: CactusAgent {
  func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, String> {
    Stream { _, continuation in
      let messageId = CactusMessageID()
      for _ in 0..<streamedTokenCount {
        continuation.yield(
          token: CactusStreamedToken(messageStreamId: messageId, stringValue: "a")
        )
        try Task.checkCancellation()
        await Task.yield()
      }
      return .collectTokensIntoOutput()
    }
  }
}

private struct FailingStreamAgent: CactusAgent {
  func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, String> {
    Stream { _, continuation in
      let messageId = CactusMessageID()
      continuation.yield(
        token: CactusStreamedToken(messageStreamId: messageId, stringValue: "a")
      )
      throw StreamTestError.boom
    }
  }
}
