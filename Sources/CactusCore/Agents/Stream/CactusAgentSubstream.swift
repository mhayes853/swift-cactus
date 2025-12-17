// MARK: - CactusAgentSubstream

public struct CactusAgentSubstream<Output: Sendable>: Sendable {
  private let stream: Task<CactusAgentStream<Output>, any Error>

  public init(_ stream: CactusAgentStream<Output>) {
    self.stream = Task { stream }
  }

  init(deferred stream: sending @escaping () async throws -> CactusAgentStream<Output>) {
    self.stream = Task { try await stream() }
  }
}

// MARK: - Substream

extension CactusAgentStream {
  public func substream<TaggedOutput>(
    as _: TaggedOutput.Type,
    for tag: some Hashable & Sendable
  ) -> CactusAgentSubstream<TaggedOutput> {
    let anyTag = AnyHashableSendable(tag)
    if let substream = self.storage.findSubstream(for: anyTag) {
      guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
        fatalError("Substream found for tag '\(tag)' does not match requested output type.")
      }
      return CactusAgentSubstream(typed)
    }

    return CactusAgentSubstream {
      let substream = try await self.storage.awaitSubstream(for: anyTag)
      guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
        fatalError("Substream found for tag '\(tag)' does not match requested output type.")
      }
      return typed
    }
  }
}

// MARK: - Response

extension CactusAgentSubstream {
  public func collectResponse() async throws -> CactusAgentResponse<Output> {
    let stream = try await self.stream.value
    return try await stream.collectResponse()
  }

  public func streamResponse() async throws -> CactusAgentStream<Output>.Response {
    let stream = try await self.stream.value
    return try await stream.streamResponse()
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
