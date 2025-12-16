public struct Stream<Input: Sendable, Output: Sendable>: CactusAgent {
  @usableFromInline
  let stream:
    @Sendable (
      CactusAgentRequest<Input>,
      CactusAgentStream<Output>.Continuation
    ) async throws -> CactusAgentStream<Output>.Response

  @inlinable
  public init(
    _ stream:
      @escaping @Sendable (
        CactusAgentRequest<Input>,
        CactusAgentStream<Output>.Continuation
      ) async throws -> CactusAgentStream<Output>.Response
  ) {
    self.stream = stream
  }

  @inlinable
  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    try await self.stream(request, continuation)
  }
}
