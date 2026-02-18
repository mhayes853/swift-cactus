import Cactus
import CustomDump
import StreamParsing
import Testing

@Suite
struct `CactusInferenceStream tests` {
  @Test
  func `Token AsyncSequence Propagates Errors`() async {
    let stream = CactusInferenceStream<String> { continuation in
      continuation.yield(
        token: CactusStreamedToken(messageStreamId: CactusMessageID(), stringValue: "a", tokenId: 0)
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
        token: CactusStreamedToken(messageStreamId: CactusMessageID(), stringValue: "a", tokenId: 0)
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
      _ = try await stream.streamResponse()
    }

    finished.withLock { result in
      _ = #expect(throws: StreamTestError.self) {
        try result?.get()
      }
    }
  }

  @Test
  func `Partials AsyncSequence Propagates Errors`() async {
    let stream = CactusInferenceStream<StreamedUser> { continuation in
      continuation.yield(partial: StreamedUser.Partial(name: "Blob", age: nil))
      throw StreamTestError.boom
    }

    let task = Task {
      var count = 0
      for try await _ in stream.partials {
        count += 1
      }
      return count
    }

    await #expect(throws: StreamTestError.self) {
      _ = try await task.value
    }
  }

  @Test
  func `OnPartial onFinished Receives Error`() async {
    let stream = CactusInferenceStream<StreamedUser> { continuation in
      continuation.yield(partial: StreamedUser.Partial(name: "Blob", age: nil))
      throw StreamTestError.boom
    }

    let finished = Lock<(any Error)?>(nil)

    let subscription = stream.onPartial(
      perform: { _ in },
      onFinished: { error in
        finished.withLock { $0 = error }
      }
    )

    _ = subscription

    await #expect(throws: StreamTestError.self) {
      _ = try await stream.streamResponse()
    }

    finished.withLock { error in
      #expect(error as? StreamTestError == .boom)
    }
  }

  @Test
  func `StreamResponse Happy Path`() async throws {
    let expectedMetric = CactusMessageMetric(
      prefillTokens: 4,
      decodeTokens: 8,
      totalTokens: 12,
      confidence: 0.9,
      prefillTps: 100,
      decodeTps: 75,
      ramUsageMb: 256,
      timeIntervalToFirstToken: 0.1,
      totalTimeInterval: 0.8
    )

    let stream = CactusInferenceStream<String> { _ in
      CactusInferenceStream<String>.Response(output: "done", metrics: expectedMetric)
    }

    let response = try await stream.streamResponse()
    expectNoDifference(response.output, "done")
    expectNoDifference(response.metrics, expectedMetric)
  }

  @Test
  func `CollectResponse Happy Path`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      CactusInferenceStream<String>.Response(output: "collected")
    }

    let response = try await stream.collectResponse()
    expectNoDifference(response, "collected")
  }

  @Test
  func `Is Streaming Is True While Stream Is Running`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds * 10)
      return CactusInferenceStream<String>.Response(output: "done")
    }

    expectNoDifference(stream.isStreaming, true)

    stream.stop()
    await #expect(throws: CancellationError.self) {
      _ = try await stream.streamResponse()
    }
  }

  @Test
  func `Is Streaming Becomes False After StreamResponse Completes`() async throws {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
      return CactusInferenceStream<String>.Response(output: "done")
    }

    expectNoDifference(stream.isStreaming, true)
    _ = try await stream.streamResponse()
    expectNoDifference(stream.isStreaming, false)
  }

  @Test
  func `Is Streaming Becomes False When Stream Is Stopped`() async {
    let stream = CactusInferenceStream<String> { _ in
      try await Task.sleep(nanoseconds: producerSleepNanoseconds)
      return CactusInferenceStream<String>.Response(output: "unreachable")
    }

    expectNoDifference(stream.isStreaming, true)
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await stream.streamResponse()
    }
    expectNoDifference(stream.isStreaming, false)
  }

  #if canImport(Observation)
    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `Is Streaming Emits Observation Updates On Completion`() async throws {
      let stream = CactusInferenceStream<String> { _ in
        try await Task.sleep(nanoseconds: cancellationLeadTimeNanoseconds)
        return CactusInferenceStream<String>.Response(output: "done")
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
        return CactusInferenceStream<String>.Response(output: "unreachable")
      }

      let values = Lock([Bool]())
      let token = observe {
        values.withLock { $0.append(stream.isStreaming) }
      }

      stream.stop()
      await #expect(throws: CancellationError.self) {
        _ = try await stream.streamResponse()
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
      let messageID = CactusMessageID()
      for _ in 0..<streamedTokenCount {
        continuation.yield(
          token: CactusStreamedToken(messageStreamId: messageID, stringValue: "a", tokenId: 0)
        )
      }
      return CactusInferenceStream<String>.Response(output: expectedOutput)
    }

    var output = ""
    for try await token in stream.tokens {
      output += token.stringValue
    }

    expectNoDifference(output, expectedOutput)
  }

  @Test
  func `Partial AsyncSequence Streams All Partials`() async throws {
    let stream = CactusInferenceStream<StreamedUser> { continuation in
      continuation.yield(partial: .init(name: "Blob", age: nil))
      continuation.yield(partial: .init(name: "Blob", age: 42))
      return CactusInferenceStream<StreamedUser>.Response(output: StreamedUser(name: "Blob", age: 42))
    }

    var collectedPartials: [StreamedUser.Partial] = []
    for try await partial in stream.partials {
      collectedPartials.append(partial)
    }
    #expect(collectedPartials.count == 2)
    expectNoDifference(collectedPartials[0].name, "Blob")
    expectNoDifference(collectedPartials[0].age, nil)
    expectNoDifference(collectedPartials[1].name, "Blob")
    expectNoDifference(collectedPartials[1].age, 42)
  }

  @Test
  func `Stop Cancels StreamResponse`() async {
    let stream = CactusInferenceStream<String> { _ in
      // NB: Keep the producer suspended long enough for the test to call `stop()` first.
      try await Task.sleep(nanoseconds: producerSleepNanoseconds)
      return CactusInferenceStream<String>.Response(output: "unreachable")
    }

    let responseTask = Task {
      try await stream.streamResponse()
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
      return CactusInferenceStream<String>.Response(output: "unreachable")
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

@StreamParseable
private struct StreamedUser: Codable, Equatable, Sendable {
  var name: String
  var age: Int
}

extension StreamedUser.Partial: Sendable {}

private enum StreamTestError: Error, Hashable {
  case boom
}
