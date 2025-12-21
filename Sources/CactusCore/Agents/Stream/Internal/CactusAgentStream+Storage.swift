import Foundation

extension CactusAgentStream {
  final class Storage: Sendable {
    struct InvalidOutputTypeError: Error {}

    private let isRootStream: Bool
    private let substreamPool: CactusAgentSubstreamPool

    private struct State {
      var streamResponseContinuations = [UnsafeContinuation<Response, any Error>]()
      var streamResponseResult: Result<Response, any Error>?
      var messageId = CactusMessageID()
      var streamedTokens = [CactusStreamedToken]()
      var tokenSubscribers = [UUID: TokenSubscriber]()
    }

    private let state = RecursiveLock(State())

    init(
      isRootStream: Bool = true,
      substreamPool: CactusAgentSubstreamPool = CactusAgentSubstreamPool()
    ) {
      self.isRootStream = isRootStream
      self.substreamPool = substreamPool
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
      self.state.withLock { state in
        state.streamedTokens.append(token)
        state.messageId = token.messageStreamId
        for subscriber in state.tokenSubscribers.values {
          subscriber.callback(token)
        }
      }
    }

    func acceptStreamResponse(_ result: Result<Response, any Error>) {
      self.state.withLock { state in
        guard state.streamResponseResult == nil else { return }
        state.streamResponseResult = result

        let finishedResult = self.finishedResult(from: result)
        for subscriber in state.tokenSubscribers.values {
          subscriber.onFinished(finishedResult)
        }
        state.tokenSubscribers.removeAll()

        state.streamResponseContinuations.forEach { $0.resume(with: result) }
        state.streamResponseContinuations.removeAll()

        if self.isRootStream {
          self.substreamPool.markWorkflowFinished()
        }
      }
    }

    func addTokenSubscriber(
      _ callback: @escaping @Sendable (CactusStreamedToken) -> Void,
      onFinished: @escaping @Sendable (Result<Output, any Error>) -> Void = { _ in }
    ) -> CactusSubscription {
      let id = UUID()

      self.state.withLock { state in
        for token in state.streamedTokens {
          callback(token)
        }

        if let streamResponseResult = state.streamResponseResult {
          onFinished(self.finishedResult(from: streamResponseResult))
        } else {
          state.tokenSubscribers[id] = TokenSubscriber(callback: callback, onFinished: onFinished)
        }
      }

      return CactusSubscription { [weak self] in
        self?.state.withLock { _ = $0.tokenSubscribers.removeValue(forKey: id) }
      }
    }

    private func apply<Target>(transforms: [Response.Transform], to value: Any) throws -> Target {
      var current = value
      for transform in transforms {
        current = try transform(current)
      }
      guard let typed = current as? Target else {
        throw Storage.InvalidOutputTypeError()
      }
      return typed
    }

    func openSubstream<SubstreamOutput: Sendable>(
      tag: AnyHashableSendable,
      namespace: CactusAgentNamespace = .global,
      run:
        @escaping @Sendable (
          CactusAgentStream<SubstreamOutput>.Continuation
        ) async throws -> CactusAgentStream<SubstreamOutput>.Response
    ) -> CactusAgentSubstream<SubstreamOutput> {
      let substream = CactusAgentStream<SubstreamOutput>(
        pool: self.substreamPool,
        isRootStream: false,
        run: run
      )
      let key = CactusAgentSubstreamPool.Key(tag: tag, namespace: namespace)
      self.substreamPool.append(substream: substream, key: key)
      return CactusAgentSubstream(substream)
    }

    func openSubstream<SubstreamOutput: Sendable>(
      run:
        @escaping @Sendable (
          CactusAgentStream<SubstreamOutput>.Continuation
        ) async throws -> CactusAgentStream<SubstreamOutput>.Response
    ) -> CactusAgentSubstream<SubstreamOutput> {
      let substream = CactusAgentStream<SubstreamOutput>(
        pool: self.substreamPool,
        isRootStream: false,
        run: run
      )
      return CactusAgentSubstream(substream)
    }

    func awaitSubstream(
      for tag: AnyHashableSendable,
      namespace: CactusAgentNamespace = .global
    ) async throws -> any Sendable {
      let key = CactusAgentSubstreamPool.Key(tag: tag, namespace: namespace)
      return try await self.substreamPool.awaitSubstream(for: key)
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
          (state.messageId, state.streamedTokens.map(\.stringValue).joined())
        }
        let cactusResponse = CactusResponse(id: responseValue.0, content: responseValue.1)
        let converted = try convertibleType.init(cactusResponse: cactusResponse)
        let finalValue: Output = try self.apply(transforms: transforms, to: converted)
        return CactusAgentResponse(output: finalValue, metrics: response.metrics)
      }
    }

    private func finishedResult(
      from result: Result<Response, any Error>
    ) -> Result<Output, any Error> {
      result.flatMap { response in
        Result { try self.agentResponse(from: response).output }
      }
    }

    private struct TokenSubscriber: Sendable {
      let callback: @Sendable (CactusStreamedToken) -> Void
      let onFinished: @Sendable (Result<Output, any Error>) -> Void
    }
  }
}
