// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  private let storage: Storage
  private let task: Task<Void, any Error>

  public init(run: sending @escaping (Continuation) async throws -> Response) {
    let storage = Storage()
    let continuation = Continuation(storage: storage)
    self.storage = storage
    self.task = Task {
      let response = try await run(continuation)
      try storage.accept(finalResponse: response)
    }
  }
}

// MARK: - Response

extension CactusAgentStream {
  public struct Response: Sendable {
    typealias _AnyTransform = @Sendable (Any) throws -> Any

    enum Action: Sendable {
      case returnOutputValue(Output)
      case collectTokensIntoOutput
    }

    let action: Action
    let metrics: CactusMessageMetrics
    let transforms: [_AnyTransform]
    let tokenOutputType: (any ConvertibleFromCactusResponse.Type)?

    init(
      action: Action,
      metrics: CactusMessageMetrics,
      transforms: [_AnyTransform] = [],
      tokenOutputType: (any ConvertibleFromCactusResponse.Type)? = nil
    ) {
      self.action = action
      self.metrics = metrics
      self.transforms = transforms
      self.tokenOutputType = tokenOutputType
    }

    func applyTransforms<Target>(to value: Any) throws -> Target {
      var current = value
      for transform in transforms {
        current = try transform(current)
      }
      guard let typed = current as? Target else {
        throw Storage.InvalidOutputTypeError()
      }
      return typed
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
        action: .collectTokensIntoOutput,
        metrics: metrics,
        tokenOutputType: Output.self
      )
    }

    public func map<NewOutput: Sendable>(
      _ transform: @escaping @Sendable (Output) throws -> NewOutput
    ) throws -> CactusAgentStream<NewOutput>.Response {
      switch self.action {
      case .returnOutputValue(let value):
        let intermediate: Output = try self.applyTransforms(to: value)
        let finalValue = try transform(intermediate)
        return .init(action: .returnOutputValue(finalValue), metrics: self.metrics)

      case .collectTokensIntoOutput:
        return .init(
          action: .collectTokensIntoOutput,
          metrics: self.metrics,
          transforms: self.transforms + [{ any in try transform(any as! Output) }],
          tokenOutputType: self.tokenOutputType
            ?? (Output.self as? any ConvertibleFromCactusResponse.Type)
        )
      }
    }
  }
}

extension CactusAgentStream {
  public func collectFinalResponse() async throws -> CactusAgentResponse<Output> {
    if let response = storage.finalResponse {
      return response
    }
    return try await withUnsafeThrowingContinuation { continuation in
      self.storage.addFinalResponseContinuation(continuation)
    }
  }

  public func collectFinalResponse<Value>(
    tag: some Hashable,
    as type: Value.Type
  ) async throws -> CactusAgentResponse<Value> {
    fatalError()
  }

  public func stop() {
    self.task.cancel()
  }
}

extension CactusAgentStream where Output: ConvertibleFromCactusResponse {
  public func collectFinalRawResponse() async throws -> CactusResponse {
    fatalError()
  }
}

// MARK: - Partials

extension CactusAgentStream
where Output: ConvertibleFromCactusResponse, Output.Partial: ConvertibleFromCactusTokenStream {
  public var finalOutputPartials: CactusAgentStreamPartials<Output.Partial> {
    CactusAgentStreamPartials()
  }

  public func onFinalOutputPartial(
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }
}

extension CactusAgentStream {
  public func responsePartials<Partial: ConvertibleFromCactusTokenStream>(
    tag: some Hashable,
    as type: Partial.Type
  ) -> CactusAgentStreamPartials<Partial> {
    CactusAgentStreamPartials()
  }

  public func onResponsePartial<Partial: ConvertibleFromCactusTokenStream>(
    tag: some Hashable,
    as type: Partial.Type,
    perform operation: (Result<Partial, any Error>) -> Void
  ) -> CactusSubscription? {
    nil
  }
}

public struct CactusAgentStreamPartials<Partial: ConvertibleFromCactusTokenStream>: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    public func next() async throws -> Partial? {
      fatalError()
    }

    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func next(isolation actor: isolated (any Actor)?) async throws -> Partial? {
      nil
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator()
  }
}

// MARK: - Tokens

extension CactusAgentStream {
  public func tokens(tag: some Hashable) -> CactusAgentStreamTokens? {
    nil
  }

  public func onResponseToken(
    tag: some Hashable,
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription? {
    nil
  }
}

extension CactusAgentStream where Output: ConvertibleFromCactusResponse {
  public var finalResponseTokens: CactusAgentStreamTokens {
    CactusAgentStreamTokens()
  }

  public func onFinalResponseToken(
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }
}

public struct CactusAgentStreamTokens: AsyncSequence {
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

// MARK: - Continuation

extension CactusAgentStream {
  public struct Continuation: Sendable {
    fileprivate let storage: Storage

    public func yield(token: CactusStreamedToken) where Output: ConvertibleFromCactusResponse {
      self.storage.accumulate(token: token)
    }

    // TODO: - Should the continuation be part of a typed stream?
    @usableFromInline
    func _unsafelyCastOutput<NewOutput>() -> CactusAgentStream<NewOutput>.Continuation {
      unsafeBitCast(self, to: CactusAgentStream<NewOutput>.Continuation.self)
    }
  }
}

// MARK: - Storage

extension CactusAgentStream {
  fileprivate final class Storage: Sendable {
    struct InvalidOutputTypeError: Error {}

    private struct State {
      var finalResponseContinuations = [
        UnsafeContinuation<CactusAgentResponse<Output>, any Error>
      ]()
      var finalResponse: CactusAgentResponse<Output>?
      var messageId = CactusMessageID()
      var finalResponseTokens = ""
    }

    private let state = Lock(State())

    var finalResponse: CactusAgentResponse<Output>? {
      self.state.withLock { $0.finalResponse }
    }

    func addFinalResponseContinuation(
      _ continuation: UnsafeContinuation<CactusAgentResponse<Output>, any Error>
    ) {
      self.state.withLock { state in
        if let finalResponse = state.finalResponse {
          continuation.resume(returning: finalResponse)
        } else {
          state.finalResponseContinuations.append(continuation)
        }
      }
    }

    func accumulate(token: CactusStreamedToken) {
      self.state.withLock {
        $0.finalResponseTokens += token.stringValue
        $0.messageId = token.messageStreamId
      }
    }

    func accept(finalResponse: Response) throws {
      try self.state.withLock { state in
        switch finalResponse.action {
        case .returnOutputValue(let value):
          let finalValue: Output = try finalResponse.applyTransforms(to: value)
          let response = CactusAgentResponse(output: finalValue, metrics: finalResponse.metrics)
          state.finalResponse = response
          state.finalResponseContinuations.forEach { $0.resume(returning: response) }
          state.finalResponseContinuations.removeAll()
        case .collectTokensIntoOutput:
          guard let convertibleType = finalResponse.tokenOutputType else {
            throw InvalidOutputTypeError()
          }

          let response = CactusResponse(id: state.messageId, content: state.finalResponseTokens)
          let converted = try convertibleType.init(cactusResponse: response)

          let finalValue: Output = try finalResponse.applyTransforms(to: converted)
          let result = Result { finalValue }
          state.finalResponseContinuations.forEach { continuation in
            continuation.resume(
              with: result.map { CactusAgentResponse(output: $0, metrics: finalResponse.metrics) }
            )
          }
          state.finalResponseContinuations.removeAll()
        }
      }
    }
  }
}
