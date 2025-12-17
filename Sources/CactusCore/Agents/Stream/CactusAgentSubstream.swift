// MARK: - CactusAgentSubstream

public struct CactusAgentSubstream<Output: Sendable>: Sendable {
  private let stream: CactusAgentStream<Output>

  public init(_ stream: CactusAgentStream<Output>) {
    self.stream = stream
  }
}

// MARK: - Substream

extension CactusAgentStream {
  public func substream<TaggedOutput>(
    as _: TaggedOutput.Type,
    for tag: some Hashable & Sendable
  ) async throws -> CactusAgentSubstream<TaggedOutput> {
    let anyTag = AnyHashableSendable(tag)
    if let substream = self.storage.findSubstream(for: anyTag) {
      guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
        throw CactusAgentStreamError.invalidSubstreamType(TaggedOutput.self)
      }
      return CactusAgentSubstream(typed)
    }

    if let parentResult = self.storage.streamResponseResult {
      switch parentResult {
      case .success:
        throw CactusAgentStreamError.missingSubstream(for: tag)
      case .failure(let error):
        throw error
      }
    }

    let substream = try await self.storage.awaitSubstream(for: anyTag)
    guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
      throw CactusAgentStreamError.invalidSubstreamType(TaggedOutput.self)
    }
    return CactusAgentSubstream(typed)
  }
}

// MARK: - Response

extension CactusAgentSubstream {
  public func collectResponse() async throws -> CactusAgentResponse<Output> {
    try await self.stream.collectResponse()
  }

  public func streamResponse() async throws -> CactusAgentStream<Output>.Response {
    try await self.stream.streamResponse()
  }
}

extension CactusAgentSubstream where Output: ConvertibleFromCactusResponse {
  public func collectRawResponse() async throws -> CactusResponse {
    fatalError()
  }
}

// MARK: - Partials

extension CactusAgentSubstream
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

extension CactusAgentSubstream where Output: ConvertibleFromCactusResponse {
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
