public struct Run<Input: Sendable, Output: Sendable>: CactusAgent {
  @usableFromInline
  let action: (Input) async throws -> Output

  @inlinable
  public init(_ action: @escaping (Input) async throws -> Output) {
    self.action = action
  }

  @inlinable
  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    let output = try await self.action(request.input)
    return .finalOutput(output)
  }
}
