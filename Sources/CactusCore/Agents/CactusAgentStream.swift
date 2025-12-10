// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  private let storage: Storage
  private let task: Task<Void, any Error>

  public init(
    graph: CactusAgentGraph,
    run: sending @escaping (Continuation) async throws -> Response
  ) {
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
    public enum Action: Sendable {
      case returnOutputValue(Output)
      case collectTokensIntoOutput
    }

    public let action: Action
    public let metrics: CactusMessageMetrics

    public static func finalOutput(
      _ value: Output,
      metrics: CactusMessageMetrics = CactusMessageMetrics()
    ) -> Self {
      Self(action: .returnOutputValue(value), metrics: metrics)
    }

    public static func collectTokensIntoOutput(
      metrics: CactusMessageMetrics = CactusMessageMetrics()
    ) -> Self where Output: ConvertibleFromCactusResponse {
      Self(action: .collectTokensIntoOutput, metrics: metrics)
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
  ) async throws -> CactusAgentResponse<Value>? {
    nil
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
  ) -> CactusAgentStreamPartials<Partial>? {
    nil
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
  }
}

// MARK: - Storage

extension CactusAgentStream {
  fileprivate final class Storage: Sendable {
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
          let response = CactusAgentResponse(output: value, metrics: finalResponse.metrics)
          state.finalResponse = response
          state.finalResponseContinuations.forEach { $0.resume(returning: response) }
          state.finalResponseContinuations.removeAll()
        case .collectTokensIntoOutput:
          func open<O: ConvertibleFromCactusResponse>(
            _ output: O.Type,
            response: CactusResponse
          ) throws -> O {
            try output.init(cactusResponse: response)
          }

          guard let output = Output.self as? any ConvertibleFromCactusResponse.Type else {
            throw InvalidOutputTypeError()
          }

          let response = CactusResponse(id: state.messageId, content: state.finalResponseTokens)
          let result = Result { try open(output, response: response) as! Output }
          state.finalResponseContinuations.forEach { continuation in
            continuation.resume(
              with: result.map { CactusAgentResponse(output: $0, metrics: finalResponse.metrics) }
            )
          }
          state.finalResponseContinuations.removeAll()
        }
      }
    }

    private struct InvalidOutputTypeError: Error {}
  }
}
