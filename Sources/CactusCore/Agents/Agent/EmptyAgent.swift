public struct EmptyAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
>: CactusAgent {
  @inlinable
  public init() {}

  @inlinable
  @inline(__always)
  public func stream(
    isolation: isolated (any Actor)?,
    input: Input,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
