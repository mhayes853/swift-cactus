// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: ConvertibleFromCactusResponse>: Sendable {
  public let continuation = Continuation()

  public init() {}

  public func collectResponse() async throws -> Output {
    fatalError()
  }

  public func collectRawResponse() async throws -> CactusResponse {
    fatalError()
  }

  public func stop() {}
}

// MARK: - OnResponseUpdate

extension CactusAgentStream where Output.Partial: ConvertibleFromCactusTokenStream {
  public func onResponseUpdate(
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }
}

// MARK: - AsyncSequence

extension CactusAgentStream: AsyncSequence where Output.Partial: ConvertibleFromCactusTokenStream {
  public struct AsyncIterator: AsyncIteratorProtocol {
    public mutating func next() async throws -> Output.Partial? {
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

// MARK: - Tokens

extension CactusAgentStream {
  public struct Tokens: AsyncSequence {
    public struct AsyncIterator: AsyncIteratorProtocol {
      public func next() async throws -> String? {
        ""
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public func next(isolation actor: isolated (any Actor)?) async throws -> String? {
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
    perform operation: (Result<String, any Error>) -> Void
  ) -> CactusSubscription {
    CactusSubscription {}
  }
}

// MARK: - Continuation

extension CactusAgentStream {
  public struct Continuation: Sendable {

  }
}
