public struct AnyAgent<Input, Output: Sendable>: CactusAgent {
  private let base: any CactusAgent<Input, Output>

  public init(_ base: any CactusAgent<Input, Output>) {
    self.base = base
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    try await self.base.stream(request: request, into: continuation)
  }
}
