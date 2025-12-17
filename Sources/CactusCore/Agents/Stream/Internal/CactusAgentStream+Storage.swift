extension CactusAgentStream {
  final class Storage: Sendable {
    struct InvalidOutputTypeError: Error {}

    private struct State {
      var streamResponseContinuations = [
        UnsafeContinuation<Response, any Error>
      ]()
      var streamResponseResult: Result<Response, any Error>?
      var messageId = CactusMessageID()
      var finalResponseTokens = ""
      var substreamPool: CactusAgentSubstreamPool?
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

    fileprivate func setSubstreamPool(_ pool: CactusAgentSubstreamPool) {
      self.state.withLock { state in
        if state.substreamPool == nil {
          state.substreamPool = pool
        }
      }
    }

    private func ensureSubstreamPool() -> CactusAgentSubstreamPool {
      self.state.withLock { state in
        if let pool = state.substreamPool {
          return pool
        }
        let pool = CactusAgentSubstreamPool()
        state.substreamPool = pool
        return pool
      }
    }
  }
}
