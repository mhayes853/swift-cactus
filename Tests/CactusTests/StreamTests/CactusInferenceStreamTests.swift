import Cactus
import CustomDump
import Testing

@Suite
struct `CactusInferenceStream tests` {
  @Test
  func `Token AsyncSequence Propagates Errors`() async {
    let stream = CactusInferenceStream<String> { continuation in
      continuation.yield(
        token: CactusStreamedToken(messageStreamId: CactusGenerationID(), stringValue: "a", tokenId: 0)
      )
      throw StreamTestError.boom
    }

    let task = Task {
      var output = ""
      for try await token in stream.tokens {
        output += token.stringValue
      }
      return output
    }

    await #expect(throws: StreamTestError.self) {
      _ = try await task.value
    }
  }

  @Test
  func `OnToken onFinished Receives Error`() async {
    let stream = CactusInferenceStream<String> { continuation in
      continuation.yield(
        token: CactusStreamedToken(messageStreamId: CactusGenerationID(), stringValue: "a", tokenId: 0)
      )
      throw StreamTestError.boom
    }

    let finished = Lock<Result<String, any Error>?>(nil)

    let subscription = stream.onToken(
      perform: { _ in },
      onFinished: { result in
        finished.withLock { $0 = result }
      }
    )

    _ = subscription

    await #expect(throws: StreamTestError.self) {
      _ = try await stream.collectResponse()
    }

    finished.withLock { result in
      _ = #expect(throws: StreamTestError.self) {
        try result?.get()
      }
    }
  }

  @Test
  func `StreamResponse Happy Path`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      "done"
    }

    let response = try await stream.collectResponse()
    expectNoDifference(response, "done")
  }

  @Test
  func `CollectResponse Happy Path`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      "collected"
    }

    let response = try await stream.collectResponse()
    expectNoDifference(response, "collected")
  }

  @Test
  func `Is Streaming Is True While Stream Is Running`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds * 10)
      return "done"
    }

    expectNoDifference(stream.isStreaming, true)

    stream.stop()
    await #expect(throws: CancellationError.self) {
      _ = try await stream.collectResponse()
    }
  }

  @Test
  func `Is Streaming Becomes False After StreamResponse Completes`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
      return "done"
    }

    expectNoDifference(stream.isStreaming, true)
    _ = try await stream.collectResponse()
    expectNoDifference(stream.isStreaming, false)
  }

  @Test
  func `Is Streaming Becomes False When Stream Is Stopped`() async {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: producerSleepNanoseconds)
      return "unreachable"
    }

    expectNoDifference(stream.isStreaming, true)
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await stream.collectResponse()
    }
    expectNoDifference(stream.isStreaming, false)
  }

  #if canImport(Observation)
    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `Is Streaming Emits Observation Updates On Completion`() async throws {
      let stream = CactusInferenceStream<String> { _ in
        try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
        return "done"
      }

      let values = Lock([Bool]())
      let token = observe {
        values.withLock { $0.append(stream.isStreaming) }
      }

      _ = try await stream.collectResponse()
      try await Task.sleep(for: .milliseconds(50))
      token.cancel()

      values.withLock {
        expectNoDifference($0, [true, false])
      }
    }

    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `Is Streaming Emits Observation Updates On Stop`() async {
      let stream = CactusInferenceStream<String> { _ in
        try await Task.sleep(nanoseconds: producerSleepNanoseconds)
        return "unreachable"
      }

      let values = Lock([Bool]())
      let token = observe {
        values.withLock { $0.append(stream.isStreaming) }
      }

      stream.stop()
      await #expect(throws: CancellationError.self) {
        _ = try await stream.collectResponse()
      }
      token.cancel()

      values.withLock {
        expectNoDifference($0, [true, false])
      }
    }
  #endif

  @Test
  func `Token AsyncSequence Streams All Tokens`() async throws {
    let expectedOutput = String(repeating: "a", count: streamedTokenCount)

    let stream = CactusInferenceStream<String> { continuation in
      let messageID = CactusGenerationID()
      for _ in 0..<streamedTokenCount {
        continuation.yield(
          token: CactusStreamedToken(messageStreamId: messageID, stringValue: "a", tokenId: 0)
        )
      }
      return expectedOutput
    }

    var output = ""
    for try await token in stream.tokens {
      output += token.stringValue
    }

    expectNoDifference(output, expectedOutput)
  }

  @Test
  func `Stop Cancels StreamResponse`() async {
    let stream = CactusInferenceStream<String> { _ in
      // NB: Keep the producer suspended long enough for the test to call `stop()` first.
      try await Task.sleep(nanoseconds: producerSleepNanoseconds)
      return "unreachable"
    }

    let responseTask = Task {
      try await stream.collectResponse()
    }

    // NB: Give the stream task a brief moment to start before triggering cancellation.
    try? await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await responseTask.value
    }
  }

  @Test
  func `Stop Cancels CollectResponse`() async {
    let stream = CactusInferenceStream<String> { _ in
      // NB: Keep the producer suspended long enough for the test to call `stop()` first.
      try await Task.sleep(nanoseconds: producerSleepNanoseconds)
      return "unreachable"
    }

    let responseTask = Task {
      try await stream.collectResponse()
    }

    // NB: Give the stream task a brief moment to start before triggering cancellation.
    try? await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await responseTask.value
    }
  }
}

private let streamedTokenCount = 256
private let producerSleepNanoseconds: UInt64 = 30_000_000_000
private let cancellationLeadTimeNanoseconds: UInt64 = 50_000_000

private enum StreamTestError: Error, Hashable {
  case boom
}
