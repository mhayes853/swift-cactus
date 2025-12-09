// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  public let continuation: Continuation
  private let storage = Storage()

  public init(graph: CactusAgentGraph) {
    self.continuation = Continuation(storage: storage)
  }

  public func collectFinalResponse() async throws -> Output {
    if let response = storage.finalResponse {
      return response
    }
    return try await withUnsafeThrowingContinuation { continuation in
      self.storage.addFinalResponseContinuation(continuation)
    }
  }

  public func collectFinalResponse<Response>(
    tag: some Hashable,
    as type: Response.Type
  ) async throws -> Response? {
    nil
  }

  public func accept(finalResponse: CactusAgentResponse<Output>) throws {
    self.storage.accept(finalResponse: finalResponse)
  }

  public func stop() {}
}

extension CactusAgentStream where Output: ConvertibleFromCactusResponse {
  public func collectFinalRawResponse() async throws -> CactusResponse {
    fatalError()
  }
}

// MARK: - Partials

extension CactusAgentStream
where Output: ConvertibleFromCactusResponse, Output.Partial: ConvertibleFromCactusTokenStream {
  public var finalResponsePartials: CactusAgentStreamPartials<Output.Partial> {
    CactusAgentStreamPartials()
  }

  public func onFinalResponsePartial(
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

    public func yield(token: CactusStreamedToken) {
      self.storage.accumulate(token: token)
    }
  }
}

// MARK: - Storage

extension CactusAgentStream {
  fileprivate final class Storage: Sendable {
    private struct State {
      var finalResponseContinuations = [UnsafeContinuation<Output, any Error>]()
      var finalResponse: Output?
      var messageId = CactusMessageID()
      var finalResponseTokens = ""
    }

    private let state = Lock(State())

    var finalResponse: Output? {
      self.state.withLock { $0.finalResponse }
    }

    func addFinalResponseContinuation(_ continuation: UnsafeContinuation<Output, any Error>) {
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

    func accept(finalResponse: CactusAgentResponse<Output>) {
      self.state.withLock { state in
        switch finalResponse.action {
        case .returnOutputValue(let value):
          state.finalResponse = value
          state.finalResponseContinuations.forEach { $0.resume(returning: value) }
          state.finalResponseContinuations.removeAll()
        case .collectTokensIntoOutput:
          func open<O: ConvertibleFromCactusResponse>(
            _ output: O.Type,
            response: CactusResponse
          ) throws -> O {
            try output.init(cactusResponse: response)
          }

          guard let output = Output.self as? any ConvertibleFromCactusResponse.Type else {
            fatalError()
          }

          let response = CactusResponse(id: state.messageId, content: state.finalResponseTokens)
          let result = Result { try open(output, response: response) as! Output }
          state.finalResponseContinuations.forEach { $0.resume(with: result) }
          state.finalResponseContinuations.removeAll()
        }
      }
    }
  }
}
