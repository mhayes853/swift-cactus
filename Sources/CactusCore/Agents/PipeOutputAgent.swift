extension CactusAgent {
  public func pipeOutput<PipedOutput, Piped: CactusAgent<Output, PipedOutput>>(
    to agent: Piped
  ) -> _PipeOutputAgent<Self, Piped> {
    _PipeOutputAgent(base: self, piped: agent)
  }

  public func pipeOutput<PipedOutput, Piped: CactusAgent<Output, PipedOutput>>(
    @CactusAgentBuilder<Output, PipedOutput> to agent: () -> Piped
  ) -> _PipeOutputAgent<Self, Piped> {
    _PipeOutputAgent(base: self, piped: agent())
  }
}

public struct _PipeOutputAgent<Base: CactusAgent, Piped: CactusAgent>: CactusAgent
where Base.Output == Piped.Input {
  let base: Base
  let piped: Piped

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Piped.Output>.Continuation
  ) async throws -> CactusAgentStream<Piped.Output>.Response {
    let transfer = UnsafeTransfer(value: request)
    let baseStream = CactusAgentStream<Base.Output> { baseContinuation in
      try await self.base.stream(request: transfer.value, into: baseContinuation)
    }
    let baseResponse = try await baseStream.collectFinalResponse()

    let pipedRequest = CactusAgentRequest(
      input: baseResponse.output,
      environment: request.environment
    )
    return try await self.piped.stream(request: pipedRequest, into: continuation)
  }
}
