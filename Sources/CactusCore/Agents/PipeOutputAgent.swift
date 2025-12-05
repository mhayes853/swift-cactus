extension CactusAgent {
  public func pipeOutput<Piped: CactusAgent>(
    to agent: Piped
  ) -> _PipeOutputAgent<Self, Piped> where Piped.Input == Output {
    _PipeOutputAgent(base: self, piped: agent)
  }

  public func pipeOutput<Piped: CactusAgent>(
    @CactusAgentBuilder<Piped.Input, Piped.Output> to agent: () -> Piped
  ) -> _PipeOutputAgent<Self, Piped> where Piped.Input == Output {
    _PipeOutputAgent(base: self, piped: agent())
  }
}

public struct _PipeOutputAgent<Base: CactusAgent, Piped: CactusAgent>: CactusAgent
where Base.Output == Piped.Input {
  let base: Base
  let piped: Piped

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Piped.Output>.Continuation
  ) async throws {
  }
}
