// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: ConvertibleFromCactusResponse>: Sendable {
  public let continuation = Continuation()

  public init() {}

  public func collectFinalResponse() async throws -> Output {
    fatalError()
  }

  public func collectFinalRawResponse() async throws -> CactusResponse {
    fatalError()
  }

  public func stop() {}
}

// MARK: - Partials

extension CactusAgentStream where Output.Partial: ConvertibleFromCactusTokenStream {
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

  public var finalResponsePartials: Partials {
    Partials()
  }

  public func onFinalResponsePartial(
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }

  public func responsePartials(tag: some Hashable) -> Partials? {
    nil
  }

  public func onResponsePartial(
    tag: some Hashable,
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription? {
    nil
  }
}

// MARK: - Tokens

extension CactusAgentStream {
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

  public var finalResponseTokens: Tokens {
    Tokens()
  }

  public func onFinalResponseToken(
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }

  public func tokens(tag: some Hashable) -> Tokens? {
    nil
  }

  public func onResponseToken(
    tag: some Hashable,
    perform operation: (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription? {
    nil
  }
}

// MARK: - Continuation

extension CactusAgentStream {
  public struct Continuation: Sendable {
  }
}
