extension CactusAgentStream {
  final class Storage: Sendable {
    struct InvalidOutputTypeError: Error {}

    private let isRootStream: Bool
    private let substreamPool: CactusAgentSubstreamPool

    private struct State {
      var streamResponseContinuations = [
        UnsafeContinuation<Response, any Error>
      ]()
      var streamResponseResult: Result<Response, any Error>?
      var messageId = CactusMessageID()
      var finalResponseTokens = ""
    }

    private let state = Lock(State())

    init(
      isRootStream: Bool = true,
      substreamPool: CactusAgentSubstreamPool = CactusAgentSubstreamPool()
    ) {
      self.isRootStream = isRootStream
      self.substreamPool = substreamPool
    }

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
        if self.isRootStream {
          self.substreamPool.markWorkflowFinished()
        }
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
      self.substreamPool.append(substream: substream, tag: tag)
    }

    func openSubstream<SubstreamOutput: Sendable>(
      tag: AnyHashableSendable,
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
      self.append(substream: substream, tag: tag)
      return CactusAgentSubstream(substream)
    }

    func awaitSubstream(for tag: AnyHashableSendable) async throws -> any Sendable {
      try await self.substreamPool.awaitSubstream(for: tag)
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
  }
}
