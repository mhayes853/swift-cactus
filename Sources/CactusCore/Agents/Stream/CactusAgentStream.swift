// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  let storage: Storage
  private let task: Task<Void, any Error>

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
    typealias _AnyTransform = @Sendable (Any) throws -> Any

    enum Action: Sendable {
      case returnOutputValue(Output)
      case collectTokensIntoOutput(Any.Type, transforms: [_AnyTransform])
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
    public struct AsyncIterator: AsyncIteratorProtocol {
      public func next() async throws -> CactusStreamedToken? {
        nil
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public func next(
        isolation actor: isolated (any Actor)?
      ) async throws -> CactusStreamedToken? {
        nil
      }
    }

    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator()
    }
  }

  public var tokens: Tokens {
    Tokens()
  }

  public func onToken(
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
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
      stream:
        @escaping @Sendable (
          CactusAgentStream<SubstreamOutput>.Continuation
        ) async throws -> CactusAgentStream<SubstreamOutput>.Response
    ) -> CactusAgentSubstream<SubstreamOutput> {
      self.storage.openSubstream(tag: AnyHashableSendable(tag), run: stream)
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
