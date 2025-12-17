// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: Sendable>: Sendable {
  private let storage: Storage
  private let task: Task<Void, any Error>

  public init(run: sending @escaping (Continuation) async throws -> Response) {
    let storage = Storage()
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

    public func append<SubstreamOutput: Sendable>(
      substream: CactusAgentStream<SubstreamOutput>,
      tag: some Hashable & Sendable
    ) {
      self.storage.append(substream: substream, tag: AnyHashableSendable(tag))
    }

    // TODO: - Should the continuation be part of a typed stream?
    @usableFromInline
    func _unsafelyCastOutput<NewOutput>() -> CactusAgentStream<NewOutput>.Continuation {
      unsafeBitCast(self, to: CactusAgentStream<NewOutput>.Continuation.self)
    }
  }
}

// MARK: - Substream

extension CactusAgentStream {
  public func substream<TaggedOutput>(
    as _: TaggedOutput.Type,
    for tag: some Hashable & Sendable
  ) -> CactusAgentStream<TaggedOutput> {
    let anyTag = AnyHashableSendable(tag)
    if let substream = self.storage.findSubstream(for: anyTag) {
      guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
        fatalError("Substream found for tag '\(tag)' does not match requested output type.")
      }
      return typed
    }

    return CactusAgentStream<TaggedOutput> { _ in
      let substream = try await self.storage.awaitSubstream(for: anyTag)
      guard let typed = substream as? CactusAgentStream<TaggedOutput> else {
        fatalError("Substream found for tag '\(tag)' does not match requested output type.")
      }
      return try await typed.streamResponse()
    }
  }
}

// MARK: - CactusAgentStreamError

public struct CactusAgentStreamError: Error, Hashable {
  private enum Reason: Hashable {
    case missingSubstream(tag: AnyHashableSendable)
  }

  private let reason: Reason

  private init(reason: Reason) {
    self.reason = reason
  }

  public static func missingSubstream(for tag: some Hashable & Sendable) -> Self {
    Self(reason: .missingSubstream(tag: AnyHashableSendable(tag)))
  }
}

// MARK: - Storage

extension CactusAgentStream {
  fileprivate final class Storage: Sendable {
    struct InvalidOutputTypeError: Error {}

    private struct State {
      var streamResponseContinuations = [
        UnsafeContinuation<Response, any Error>
      ]()
      var streamResponseResult: Result<Response, any Error>?
      var messageId = CactusMessageID()
      var finalResponseTokens = ""
      var substreamPool: SubstreamPool?
    }

    private let state = Lock(State())

    var streamResponseResult: Result<Response, any Error>? {
      self.state.withLock { $0.streamResponseResult }
    }

    func addStreamResponseContinuation(
      _ continuation: UnsafeContinuation<Response, any Error>
    ) {
      self.state.withLock { state in
        if let streamResponse = state.streamResponseResult {
          continuation.resume(with: streamResponse)
        } else {
          state.streamResponseContinuations.append(continuation)
        }
      }
    }

    func accumulate(token: CactusStreamedToken) {
      self.state.withLock {
        $0.finalResponseTokens += token.stringValue
        $0.messageId = token.messageStreamId
      }
    }

    func acceptStreamResponse(_ result: Result<Response, any Error>) {
      self.state.withLock { state in
        guard state.streamResponseResult == nil else { return }
        state.streamResponseResult = result
        state.streamResponseContinuations.forEach { $0.resume(with: result) }
        state.streamResponseContinuations.removeAll()
        self.failPendingSubstreamsIfNeeded(state: &state)
      }
    }

    private func apply<Target>(
      transforms: [Response._AnyTransform],
      to value: Any
    ) throws -> Target {
      var current = value
      for transform in transforms {
        current = try transform(current)
      }
      guard let typed = current as? Target else {
        throw Storage.InvalidOutputTypeError()
      }
      return typed
    }

    func append<SubstreamOutput: Sendable>(
      substream: CactusAgentStream<SubstreamOutput>,
      tag: AnyHashableSendable
    ) {
      let pool = self.ensureSubstreamPool()
      substream.storage.setSubstreamPool(pool)
      let continuations = pool.append(substream: substream, tag: tag)
      continuations.forEach { $0.resume(returning: substream) }
    }

    func findSubstream(for tag: AnyHashableSendable) -> (any Sendable)? {
      guard let pool = self.state.withLock({ $0.substreamPool }) else { return nil }
      return pool.findSubstream(for: tag)
    }

    func awaitSubstream(for tag: AnyHashableSendable) async throws -> any Sendable {
      let pool = self.ensureSubstreamPool()
      return try await pool.awaitSubstream(for: tag)
    }

    func agentResponse(from response: Response) throws -> CactusAgentResponse<Output> {
      switch response.action {
      case .returnOutputValue(let value):
        return CactusAgentResponse(output: value, metrics: response.metrics)

      case .collectTokensIntoOutput(let outputType, let transforms):
        guard let convertibleType = outputType as? any ConvertibleFromCactusResponse.Type else {
          throw InvalidOutputTypeError()
        }

        let responseValue = self.state.withLock { state in
          (state.messageId, state.finalResponseTokens)
        }
        let cactusResponse = CactusResponse(
          id: responseValue.0,
          content: responseValue.1
        )
        let converted = try convertibleType.init(cactusResponse: cactusResponse)
        let finalValue: Output = try self.apply(transforms: transforms, to: converted)
        return CactusAgentResponse(output: finalValue, metrics: response.metrics)
      }
    }

    private func failPendingSubstreamsIfNeeded(state: inout State) {
      guard let pool = state.substreamPool else { return }
      pool.failPendingSubstreams()
    }

    fileprivate func setSubstreamPool(_ pool: SubstreamPool) {
      self.state.withLock { state in
        if state.substreamPool == nil {
          state.substreamPool = pool
        }
      }
    }

    private func ensureSubstreamPool() -> SubstreamPool {
      self.state.withLock { state in
        if let pool = state.substreamPool {
          return pool
        }
        let pool = SubstreamPool()
        state.substreamPool = pool
        return pool
      }
    }
  }
}

// MARK: - Substream Pool

private final class SubstreamPool: Sendable {
  private struct State {
    var substreams = [AnyHashableSendable: any Sendable]()
    var pending = [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]]()
  }

  private let state = Lock(State())

  func append(
    substream: any Sendable,
    tag: AnyHashableSendable
  ) -> [UnsafeContinuation<any Sendable, any Error>] {
    self.state.withLock { state in
      state.substreams[tag] = substream
      return state.pending.removeValue(forKey: tag) ?? []
    }
  }

  func findSubstream(for tag: AnyHashableSendable) -> (any Sendable)? {
    self.state.withLock { state in
      state.substreams[tag]
    }
  }

  func awaitSubstream(for tag: AnyHashableSendable) async throws -> any Sendable {
    if let found = self.findSubstream(for: tag) {
      return found
    }

    return try await withUnsafeThrowingContinuation { continuation in
      let found = self.state.withLock { state -> (any Sendable)? in
        if let direct = state.substreams[tag] {
          return direct
        } else {
          state.pending[tag, default: []].append(continuation)
          return nil
        }
      }

      guard let found else { return }
      continuation.resume(returning: found)
    }
  }

  func failPendingSubstreams() {
    let pending = self.state.withLock { state -> [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]] in
      let current = state.pending
      state.pending.removeAll()
      return current
    }

    guard !pending.isEmpty else { return }

    for (tag, continuations) in pending {
      let error = CactusAgentStreamError.missingSubstream(for: tag)
      continuations.forEach { $0.resume(throwing: error) }
    }
  }
}

// MARK: - Substream Lookup

private protocol _SubstreamLookup: Sendable {
  func _findSubstream(for tag: AnyHashableSendable) -> (any Sendable)?
}

extension CactusAgentStream: _SubstreamLookup {
  fileprivate func _findSubstream(for tag: AnyHashableSendable) -> (any Sendable)? {
    self.storage.findSubstream(for: tag)
  }
}
