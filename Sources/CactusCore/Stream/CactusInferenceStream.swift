import Foundation

// MARK: - CactusInferenceStream

/// A lightweight async stream for model inference output, token events, and optional partial events.
public struct CactusInferenceStream<Output: Sendable>: Sendable {
  private let storage: Storage
  private let task: Task<Void, Never>

  /// Creates an inference stream from an async producer closure.
  ///
  /// - Parameter run: A closure that receives a continuation for yielding tokens/partials and
  ///   returns the final response when inference completes.
  public init(run: sending @escaping (Continuation) async throws -> Response) {
    let storage = Storage()
    let continuation = Continuation(storage: storage)
    self.storage = storage
    self.task = Task {
      do {
        let response = try await run(continuation)
        storage.acceptStreamResponse(.success(response))
      } catch {
        storage.acceptStreamResponse(.failure(error))
      }
    }
  }
}

// MARK: - Response

extension CactusInferenceStream {
  /// The final response produced by an inference stream.
  public struct Response: Sendable {
    /// The final output value.
    public let output: Output

    /// Metrics associated with the output generation.
    public let metrics: CactusMessageMetric

    /// Creates a response.
    ///
    /// - Parameters:
    ///   - output: The final output value.
    ///   - metrics: Inference metrics for the output.
    public init(output: Output, metrics: CactusMessageMetric = CactusMessageMetric()) {
      self.output = output
      self.metrics = metrics
    }
  }
}

// MARK: - Public API

extension CactusInferenceStream {
  /// Waits for and returns the final stream response.
  ///
  /// - Returns: The final response.
  public func streamResponse() async throws -> Response {
    try await withUnsafeThrowingContinuation { continuation in
      self.storage.addStreamResponseContinuation(continuation)
    }
  }

  /// Waits for and returns just the final output value.
  ///
  /// - Returns: The final output value.
  public func collectResponse() async throws -> Output {
    try await self.streamResponse().output
  }

  /// Stops the stream and cancels any in-flight work.
  public func stop() {
    self.task.cancel()
    self.storage.cancel(CancellationError())
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

// MARK: - Partials

extension CactusInferenceStream where Output: StreamParseable, Output.Partial: Sendable {
  /// An async sequence of streamed partial values.
  public struct Partials: AsyncSequence {
    let storage: Storage

    /// An iterator over streamed partials.
    public struct AsyncIterator: AsyncIteratorProtocol {
      var base: AsyncThrowingStream<Output.Partial, any Error>.AsyncIterator

      public mutating func next() async throws -> Output.Partial? {
        try await self.base.next()
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public mutating func next(
        isolation actor: isolated (any Actor)?
      ) async throws -> Output.Partial? {
        try await self.base.next(isolation: actor)
      }
    }

    /// Creates an iterator for streamed partials.
    public func makeAsyncIterator() -> AsyncIterator {
      let (stream, continuation) = AsyncThrowingStream<Output.Partial, any Error>.makeStream()
      let subscription = self.storage.addPartialSubscriber { partial in
        continuation.yield(partial)
      } onFinished: { error in
        if let error {
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

  /// A partial event stream for this inference stream.
  public var partials: Partials {
    Partials(storage: self.storage)
  }

  /// Subscribes to streamed partial events.
  ///
  /// - Parameters:
  ///   - operation: Called for every streamed partial.
  ///   - onFinished: Called once when streaming completes or fails.
  /// - Returns: A subscription that can cancel the callbacks.
  public func onPartial(
    perform operation: @escaping @Sendable (Output.Partial) -> Void,
    onFinished: @escaping @Sendable ((any Error)?) -> Void = { _ in }
  ) -> CactusSubscription {
    self.storage.addPartialSubscriber(operation, onFinished: onFinished)
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

extension CactusInferenceStream.Continuation
where Output: StreamParseable, Output.Partial: Sendable {
  /// Emits a partial value to partial subscribers.
  ///
  /// - Parameter partial: The partial value to emit.
  public func yield(partial: Output.Partial) {
    self.storage.accumulate(partial: partial)
  }
}

// MARK: - Storage

extension CactusInferenceStream {
  final class Storage: Sendable {
    private struct State {
      var streamResponseContinuations = [UnsafeContinuation<Response, any Error>]()
      var streamResponseResult: Result<Response, any Error>?
      var streamedTokens = [CactusStreamedToken]()
      var tokenSubscribers = [UUID: TokenSubscriber]()
      var streamedPartials = [any Sendable]()
      var partialSubscribers = [UUID: PartialSubscriber]()
    }

    private let state = RecursiveLock(State())

    func addStreamResponseContinuation(_ continuation: UnsafeContinuation<Response, any Error>) {
      self.state.withLock { state in
        if let streamResponseResult = state.streamResponseResult {
          continuation.resume(with: streamResponseResult)
        } else {
          state.streamResponseContinuations.append(continuation)
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

    func accumulate(partial: any Sendable) {
      self.state.withLock { state in
        state.streamedPartials.append(partial)
        for subscriber in state.partialSubscribers.values {
          subscriber.callback(partial)
        }
      }
    }

    func acceptStreamResponse(_ result: Result<Response, any Error>) {
      self.state.withLock { state in
        guard state.streamResponseResult == nil else { return }
        state.streamResponseResult = result

        let finishedResult = result.map(\.output)
        for subscriber in state.tokenSubscribers.values {
          subscriber.onFinished(finishedResult)
        }
        state.tokenSubscribers.removeAll()

        let partialFinishedError = result.failure
        for subscriber in state.partialSubscribers.values {
          subscriber.onFinished(partialFinishedError)
        }
        state.partialSubscribers.removeAll()

        for continuation in state.streamResponseContinuations {
          continuation.resume(with: result)
        }
        state.streamResponseContinuations.removeAll()
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

        if let streamResponseResult = state.streamResponseResult {
          onFinished(streamResponseResult.map(\.output))
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

    private struct PartialSubscriber: Sendable {
      let callback: @Sendable (any Sendable) -> Void
      let onFinished: @Sendable ((any Error)?) -> Void
    }
  }
}

extension CactusInferenceStream.Storage where Output: StreamParseable, Output.Partial: Sendable {
  func addPartialSubscriber(
    _ callback: @escaping @Sendable (Output.Partial) -> Void,
    onFinished: @escaping @Sendable ((any Error)?) -> Void = { _ in }
  ) -> CactusSubscription {
    let id = UUID()

    self.state.withLock { state in
      for partial in state.streamedPartials {
        guard let typedPartial = partial as? Output.Partial else { continue }
        callback(typedPartial)
      }

      if let streamResponseResult = state.streamResponseResult {
        onFinished(streamResponseResult.failure)
      } else {
        state.partialSubscribers[id] = PartialSubscriber(
          callback: { partial in
            guard let typedPartial = partial as? Output.Partial else { return }
            callback(typedPartial)
          },
          onFinished: onFinished
        )
      }
    }

    return CactusSubscription { [weak self] in
      self?.state.withLock { _ = $0.partialSubscribers.removeValue(forKey: id) }
    }
  }
}
