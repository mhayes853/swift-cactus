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
    for tag: some Hashable & Sendable,
    namespace: CactusAgentNamespace = .global
  ) async throws -> CactusAgentSubstream<TaggedOutput> {
    let substream = try await self.storage.awaitSubstream(
      for: AnyHashableSendable(tag),
      namespace: namespace
    )
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
    try await self.stream.collectRawResponse()
  }
}

// MARK: - Partials

extension CactusAgentSubstream
where Output: ConvertibleFromCactusResponse, Output.Partial: ConvertibleFromCactusTokenStream {
  public struct Partials: AsyncSequence {
    let base: CactusAgentStream<Output>.Partials

    public struct AsyncIterator: AsyncIteratorProtocol {
      var base: CactusAgentStream<Output>.Partials.AsyncIterator

      public func next() async throws -> Output.Partial? {
        try await self.base.next()
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public func next(isolation actor: isolated (any Actor)?) async throws -> Output.Partial? {
        try await self.base.next(isolation: actor)
      }
    }

    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(base: self.base.makeAsyncIterator())
    }
  }

  public var partials: Partials {
    Partials(base: self.stream.partials)
  }

  public func onPartial(
    perform operation: (Result<Output.Partial, any Error>) -> Void
  ) -> CactusSubscription {
    self.stream.onPartial(perform: operation)
  }
}

// MARK: - Tokens

extension CactusAgentSubstream where Output: ConvertibleFromCactusResponse {
  public struct Tokens: AsyncSequence {
    let base: CactusAgentStream<Output>.Tokens

    public struct AsyncIterator: AsyncIteratorProtocol {
      var base: CactusAgentStream<Output>.Tokens.AsyncIterator

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
      AsyncIterator(base: self.base.makeAsyncIterator())
    }
  }

  public var tokens: Tokens {
    Tokens(base: self.stream.tokens)
  }

  public func onToken(
    perform operation: @escaping @Sendable (Result<CactusStreamedToken, any Error>) -> Void
  ) -> CactusSubscription {
    self.stream.onToken(perform: operation)
  }
}
