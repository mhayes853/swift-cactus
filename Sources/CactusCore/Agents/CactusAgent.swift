public protocol CactusAgent<Input, Output> {
  associatedtype Input: CactusPromptRepresentable
  associatedtype Output: ConvertibleFromCactusResponse

  associatedtype Body

  @CactusAgentBuilder<Input, Output>
  func body(request: CactusAgentRequest<Input>) -> Body

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws
}

extension CactusAgent where Body == Never {
  @_transparent
  public func body(request: CactusAgentRequest<Input>) -> Never {
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not access an agent's 'body' property directly, as it may not exist. To run an agent, \
      call 'CactusAgent.stream(isolation:input:into:)', instead.
      """
    )
  }
}

extension CactusAgent where Body: CactusAgent<Input, Output> {
  @inlinable
  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
    try await self.body(request: request)
      .stream(request: request, into: continuation)
  }
}
