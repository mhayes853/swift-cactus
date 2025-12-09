// MARK: - CactusAgentStream

public struct CactusAgentStream<Output>: Sendable {
  public let continuation = Continuation()

  public init(graph: CactusAgentGraph) {}

  public func collectFinalResponse() async throws -> Output {
    fatalError()
  }

  public func collectFinalRawResponse() async throws -> CactusResponse {
    fatalError()
  }

  public func collectFinalResponse<Response>(
    tag: some Hashable,
    as type: Response.Type
  ) async throws -> Response? {
    nil
  }

  public func stop() {}
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
  public var finalResponseTokens: CactusAgentStreamTokens {
    CactusAgentStreamTokens()
  }

  public func onFinalResponseToken(
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }

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
  }
}
