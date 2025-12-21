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
      let errorCount = Lock(0)

      let subscription = stream.onToken { result in
        switch result {
        case .success(let token):
          output.withLock { $0 += token.stringValue }
        case .failure:
          errorCount.withLock { $0 += 1 }
        }
      }

      _ = subscription

      _ = try await stream.streamResponse()

      output.withLock { expectNoDifference($0, expectedStreamedOutput) }
      errorCount.withLock { expectNoDifference($0, 0) }
    }

    @Test
    func `OnToken Callback Can Cancel Subscription`() async throws {
      let session = CactusAgenticSession(CharacterStreamedAgent())
      let stream = session.stream()

      let output = Lock("")
      let subscription = Lock<CactusSubscription?>(nil)

      subscription.withLock {
        $0 = stream.onToken { result in
          switch result {
          case .success(let token):
            let count = output.withLock { output in
              output += token.stringValue
              return output.count
            }
            if count >= streamedTokenCount / 2 {
              subscription.withLock { $0?.cancel() }
            }
          case .failure:
            break
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

      let subscription = stream.onToken { result in
        switch result {
        case .success(let token):
          let count = output.withLock { output in
            output += token.stringValue
            return output.count
          }
          if count >= streamedTokenCount / 2 {
            stream.stop()
          }
        case .failure:
          break
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
  }
}

private let streamedTokenCount = 4096
private let expectedStreamedOutput = String(repeating: "a", count: streamedTokenCount)

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
