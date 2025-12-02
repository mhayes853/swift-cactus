public protocol CactusAgent<Input, Output> {
  associatedtype Input: CactusPromptRepresentable
  associatedtype Output: ConvertibleFromCactusResponse

  associatedtype Body

  @CactusAgentBuilder<Input, Output>
  func body(input: Input) -> Body

  nonisolated(nonsending) func stream(
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws
}

extension CactusAgent where Body == Never {
  @_transparent
  public func body(input: Input) -> Never {
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
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
    try await self.body(input: input)
      .stream(input: input, into: continuation)
  }
}
