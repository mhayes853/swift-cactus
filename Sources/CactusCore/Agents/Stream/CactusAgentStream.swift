// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  let storage: Storage
  private let task: Task<Void, Never>

  public init(run: sending @escaping (Continuation) async throws -> Response) {
    self.init(pool: CactusAgentSubstreamPool(), isRootStream: true, run: run)
  }

  init(
    pool: CactusAgentSubstreamPool,
    isRootStream: Bool = false,
    run: sending @escaping (Continuation) async throws -> Response
  ) {
    let storage = Storage(isRootStream: isRootStream, substreamPool: pool)
    let continuation = Continuation(storage: storage)
    self.storage = storage
    self.task = Task {
      storage.acceptStreamResponse(await Result { try await run(continuation) })
    }
  }
}

// MARK: - Response

extension CactusAgentStream {
  public struct Response: Sendable {
    typealias Transform = @Sendable (Any) throws -> Any

    enum Action: Sendable {
      case returnOutputValue(Output)
      case collectTokensIntoOutput(Any.Type, transforms: [Transform])
    }

    let action: Action
    let metrics: CactusMessageMetrics

    init(action: Action, metrics: CactusMessageMetrics) {
      self.action = action
      self.metrics = metrics
    }

    public static func finalOutput(
      _ value: Output,
      metrics: CactusMessageMetrics = CactusMessageMetrics()
    ) -> Self {
      Self(action: .returnOutputValue(value), metrics: metrics)
    }

    public static func collectTokensIntoOutput(
      metrics: CactusMessageMetrics = CactusMessageMetrics()
    ) -> Self where Output: ConvertibleFromCactusResponse {
      Self(
        action: .collectTokensIntoOutput(Output.self, transforms: []),
        metrics: metrics
      )
    }

    public func map<NewOutput: Sendable>(
      _ transform: @escaping @Sendable (Output) throws -> NewOutput
    ) throws -> CactusAgentStream<NewOutput>.Response {
      switch self.action {
      case .returnOutputValue(let value):
        CactusAgentStream<NewOutput>
          .Response(action: .returnOutputValue(try transform(value)), metrics: self.metrics)

      case .collectTokensIntoOutput(let tokenOutputType, let transforms):
        CactusAgentStream<NewOutput>
          .Response(
            action: .collectTokensIntoOutput(
              tokenOutputType,
              transforms: transforms + [{ any in try transform(any as! Output) }]
            ),
            metrics: self.metrics
          )
      }
    }
  }
}

extension CactusAgentStream {
  public func collectResponse() async throws -> CactusAgentResponse<Output> {
    let response = try await self.streamResponse()
    return try self.storage.agentResponse(from: response)
  }

  public func stop() {
    self.task.cancel()
  }

  public func streamResponse() async throws -> Response {
    try await withUnsafeThrowingContinuation { continuation in
      self.storage.addStreamResponseContinuation(continuation)
    }
  }
}

extension CactusAgentStream where Output: ConvertibleFromCactusResponse {
  public func collectRawResponse() async throws -> CactusResponse {
    fatalError()
  }
}

// MARK: - Partials

extension CactusAgentStream
where Output: ConvertibleFromCactusResponse, Output.Partial: ConvertibleFromCactusTokenStream {
  public struct Partials: AsyncSequence {
    public struct AsyncIterator: AsyncIteratorProtocol {
      public func next() async throws -> Output.Partial? {
        fatalError()
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public func next(isolation actor: isolated (any Actor)?) async throws -> Output.Partial? {
        nil
      }
    }

    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator()
    }
  }

  public var partials: Partials {
    Partials()
  }

  public func onPartial(
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }
}

// MARK: - Tokens

extension CactusAgentStream where Output: ConvertibleFromCactusResponse {
  public struct Tokens: AsyncSequence {
    let storage: Storage

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

    public func makeAsyncIterator() -> AsyncIterator {
      let (stream, continuation) = AsyncThrowingStream<CactusStreamedToken, any Error>.makeStream()
      let subscription = self.storage.addTokenSubscriber { token in
        continuation.yield(token)
      } onFinished: { result in
        switch result {
        case .success:
          continuation.finish()
        case .failure(let error):
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { t in
        subscription.cancel()
        switch t {
        case .cancelled:
          continuation.finish(throwing: CancellationError())
        default:
          break
        }
      }
      return AsyncIterator(base: stream.makeAsyncIterator())
    }
  }

  public var tokens: Tokens {
    Tokens(storage: self.storage)
  }

  public func onToken(
    perform operation: @escaping @Sendable (CactusStreamedToken) -> Void,
    onFinished: @escaping @Sendable (Result<Output, any Error>) -> Void = { _ in }
  ) -> CactusSubscription {
    self.storage.addTokenSubscriber(operation, onFinished: onFinished)
  }
}

// MARK: - Continuation

extension CactusAgentStream {
  public struct Continuation: Sendable {
    fileprivate let storage: Storage

    public func yield(token: CactusStreamedToken) where Output: ConvertibleFromCactusResponse {
      self.storage.accumulate(token: token)
    }

    public func openSubstream<SubstreamOutput: Sendable>(
      tag: some Hashable & Sendable,
      namespace: CactusAgentNamespace = .global,
      stream:
        @escaping @Sendable (
          CactusAgentStream<SubstreamOutput>.Continuation
        ) async throws -> CactusAgentStream<SubstreamOutput>.Response
    ) -> CactusAgentSubstream<SubstreamOutput> {
      self.storage.openSubstream(
        tag: AnyHashableSendable(tag),
        namespace: namespace,
        run: stream
      )
    }

    public func openSubstream<SubstreamOutput: Sendable>(
      _ stream:
        @escaping @Sendable (
          CactusAgentStream<SubstreamOutput>.Continuation
        ) async throws -> CactusAgentStream<SubstreamOutput>.Response
    ) -> CactusAgentSubstream<SubstreamOutput> {
      self.storage.openSubstream(run: stream)
    }

    // TODO: - Should the continuation be part of a typed stream?
    @usableFromInline
    func _unsafelyCastOutput<NewOutput>() -> CactusAgentStream<NewOutput>.Continuation {
      unsafeBitCast(self, to: CactusAgentStream<NewOutput>.Continuation.self)
    }
  }
}

// MARK: - CactusAgentStreamError

public struct CactusAgentStreamError: Error, Hashable {
  private enum Reason: Hashable {
    case missingSubstream(tag: AnyHashableSendable)
    case invalidSubstreamType(HashableType)
  }

  private let reason: Reason

  private init(reason: Reason) {
    self.reason = reason
  }

  public static func missingSubstream(for tag: some Hashable & Sendable) -> Self {
    Self(reason: .missingSubstream(tag: AnyHashableSendable(tag)))
  }

  public static func invalidSubstreamType(_ outputType: Any.Type) -> Self {
    Self(reason: .invalidSubstreamType(HashableType(outputType)))
  }
}
