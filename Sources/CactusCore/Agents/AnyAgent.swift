public struct AnyAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  private let base: any CactusAgent<Input, Output>

  public init(_ base: any CactusAgent<Input, Output>) {
    self.base = base
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
    try await self.base.stream(request: request, into: continuation)
  }
}
