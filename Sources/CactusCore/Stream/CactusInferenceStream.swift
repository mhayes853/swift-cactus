import Foundation

// MARK: - CactusInferenceStream

/// A lightweight async stream for model inference output and token events.
///
/// ``CactusAgentSession`` streaming.
///
/// ```swift
/// let session = try CactusAgentSession(from: modelURL) {
///   "You are a helpful assistant."
/// }
///
/// let message = CactusUserMessage {
///   "What is the weather in San Francisco?"
/// }
/// let stream = try session.stream(to: message)
/// for await token in stream.tokens {
///   print(token.stringValue, token.tokenId, token.generationStreamId)
/// }
///
/// let completion = try await stream.collectResponse()
/// print(completion.output)
/// ```
///
/// ``CactusSTTSession`` streaming.
///
/// ```swift
/// let session = try CactusSTTSession(from: modelURL)
///
/// let request = CactusTranscription.Request(
///   prompt: .default,
///   content: .audio(.documentsDirectory.appending(path: "audio.wav"))
/// )
/// let stream = try session.transcriptionStream(request: request)
/// for await token in stream.tokens {
///   print(token.stringValue, token.tokenId, token.generationStreamId)
/// }
///
/// let transcription = try await stream.collectResponse()
/// print(transcription.content)
/// ```
public final class CactusInferenceStream<Output: Sendable>: Sendable {
  private let observationRegistrar = _ObservationRegistrar()
  private let state = Lock(State())
  private let storage: Storage
  private let task: Task<Void, Never>

  private struct State {
    var isStreaming = true
  }

  /// Creates an inference stream from an async producer closure.
  ///
  /// - Parameter run: A closure that receives a continuation for yielding tokens and
  ///   returns the final output when inference completes.
  public init(run: sending @escaping (Continuation) async throws -> Output) {
    let storage = Storage()
    let continuation = Continuation(storage: storage)
    self.storage = storage
    self.task = Task {
      do {
        let output = try await run(continuation)
        storage.acceptStreamResponse(.success(output))
      } catch {
        storage.acceptStreamResponse(.failure(error))
      }
    }
    self.storage.setOnStreamFinished { [weak self] in
      self?.markStreamingFinished()
    }
  }
}

// MARK: - Public API

extension CactusInferenceStream {
  /// Indicates whether this stream is still producing output.
  public var isStreaming: Bool {
    self.observationRegistrar.access(self, keyPath: \.isStreaming)
    return self.state.withLock { $0.isStreaming }
  }

  /// Waits for and returns the final output value.
  ///
  /// - Returns: The final output value.
  public func collectResponse() async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
      self.storage.addOutputContinuation(continuation)
    }
  }

  /// Stops the stream and cancels any in-flight work.
  public func stop() {
    self.task.cancel()
    self.storage.cancel(CancellationError())
  }

  private func markStreamingFinished() {
    self.observationRegistrar.withMutation(of: self, keyPath: \.isStreaming) {
      self.state.withLock { state in
        guard state.isStreaming else { return }
        state.isStreaming = false
      }
    }
  }
}

// MARK: - Tokens

extension CactusInferenceStream {
  /// An async sequence of streamed token events.
  public struct Tokens: AsyncSequence {
    let storage: Storage

    /// An iterator over streamed tokens.
    public struct AsyncIterator: AsyncIteratorProtocol {
      var base: AsyncThrowingStream<CactusStreamedToken, any Error>.AsyncIterator

      public mutating func next() async throws -> CactusStreamedToken? {
        try await self.base.next()
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public mutating func next(
        isolation actor: isolated (any Actor)?
      ) async throws -> CactusStreamedToken? {
        try await self.base.next(isolation: actor)
      }
    }

    /// Creates an iterator for streamed tokens.
    public func makeAsyncIterator() -> AsyncIterator {
      let (stream, continuation) = AsyncThrowingStream<CactusStreamedToken, any Error>.makeStream()
      let subscription = self.storage.addTokenSubscriber { token in
        continuation.yield(token)
      } onFinished: { result in
        if let error = result.failure {
          continuation.finish(throwing: error)
        } else {
          continuation.finish()
        }
      }
      continuation.onTermination = { _ in
        subscription.cancel()
      }
      return AsyncIterator(base: stream.makeAsyncIterator())
    }
  }

  /// A token event stream for this inference stream.
  public var tokens: Tokens {
    Tokens(storage: self.storage)
  }

  /// Subscribes to streamed token events.
  ///
  /// - Parameters:
  ///   - operation: Called for every streamed token.
  ///   - onFinished: Called once with either the final output or an error.
  /// - Returns: A subscription that can cancel the callbacks.
  public func onToken(
    perform operation: @escaping @Sendable (CactusStreamedToken) -> Void,
    onFinished: @escaping @Sendable (Result<Output, any Error>) -> Void = { _ in }
  ) -> CactusSubscription {
    self.storage.addTokenSubscriber(operation, onFinished: onFinished)
  }
}

// MARK: - Continuation

extension CactusInferenceStream {
  /// A continuation used by the producer closure to emit stream events.
  public struct Continuation: Sendable {
    fileprivate let storage: Storage

    /// Emits a token event to token subscribers.
    ///
    /// - Parameter token: The token to emit.
    public func yield(token: CactusStreamedToken) {
      self.storage.accumulate(token: token)
    }
  }
}

// MARK: - Storage

extension CactusInferenceStream {
  final class Storage: Sendable {
    private struct State {
      var outputContinuations = [UnsafeContinuation<Output, any Error>]()
      var outputResult: Result<Output, any Error>?
      var streamedTokens = [CactusStreamedToken]()
      var tokenSubscribers = [UUID: TokenSubscriber]()
      var onStreamFinished: @Sendable () -> Void = {}
    }

    private let state = RecursiveLock(State())

    func setOnStreamFinished(_ operation: @escaping @Sendable () -> Void) {
      self.state.withLock { $0.onStreamFinished = operation }
    }

    func addOutputContinuation(_ continuation: UnsafeContinuation<Output, any Error>) {
      self.state.withLock { state in
        if let outputResult = state.outputResult {
          continuation.resume(with: outputResult)
        } else {
          state.outputContinuations.append(continuation)
        }
      }
    }

    func accumulate(token: CactusStreamedToken) {
      self.state.withLock { state in
        state.streamedTokens.append(token)
        for subscriber in state.tokenSubscribers.values {
          subscriber.callback(token)
        }
      }
    }

    func acceptStreamResponse(_ result: Result<Output, any Error>) {
      self.state.withLock { state in
        guard state.outputResult == nil else { return }
        state.outputResult = result

        for subscriber in state.tokenSubscribers.values {
          subscriber.onFinished(result)
        }
        state.tokenSubscribers.removeAll()

        for continuation in state.outputContinuations {
          continuation.resume(with: result)
        }
        state.outputContinuations.removeAll()

        state.onStreamFinished()
      }
    }

    func cancel(_ error: any Error) {
      self.acceptStreamResponse(.failure(error))
    }

    func addTokenSubscriber(
      _ callback: @escaping @Sendable (CactusStreamedToken) -> Void,
      onFinished: @escaping @Sendable (Result<Output, any Error>) -> Void = { _ in }
    ) -> CactusSubscription {
      let id = UUID()

      self.state.withLock { state in
        for token in state.streamedTokens {
          callback(token)
        }

        if let outputResult = state.outputResult {
          onFinished(outputResult)
        } else {
          state.tokenSubscribers[id] = TokenSubscriber(callback: callback, onFinished: onFinished)
        }
      }

      return CactusSubscription { [weak self] in
        self?.state.withLock { _ = $0.tokenSubscribers.removeValue(forKey: id) }
      }
    }

    private struct TokenSubscriber: Sendable {
      let callback: @Sendable (CactusStreamedToken) -> Void
      let onFinished: @Sendable (Result<Output, any Error>) -> Void
    }
  }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusInferenceStream: _Observable {}
