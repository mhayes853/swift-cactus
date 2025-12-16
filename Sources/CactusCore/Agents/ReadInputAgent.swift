public struct ReadInput<Input, Output: Sendable, Child: CactusAgent>: CactusAgent
where Child.Input == Input, Child.Output == Output {
  @usableFromInline
  let child: @Sendable (Input) -> Child

  @inlinable
  public init(
    @CactusAgentBuilder<Input, Output> child: @escaping @Sendable (Input) -> Child
  ) {
    self.child = child
  }

  @inlinable
  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Child.Input>,
    into continuation: CactusAgentStream<Child.Output>.Continuation
  ) async throws -> CactusAgentStream<Child.Output>.Response {
    try await self.child(request.input).stream(request: request, into: continuation)
  }
}
