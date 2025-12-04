// MARK: - CactusAgentBuilder

@resultBuilder
public enum CactusAgentBuilder<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
> {
  public static func buildBlock() -> EmptyAgent<Input, Output> {
    EmptyAgent()
  }

  public static func buildEither<AL: CactusAgent<Input, Output>, AR: CactusAgent<Input, Output>>(
    first component: AL
  ) -> _EitherAgent<AL, AR> {
    .left(component)
  }

  public static func buildEither<AL: CactusAgent<Input, Output>, AR: CactusAgent<Input, Output>>(
    seconds component: AR
  ) -> _EitherAgent<AL, AR> {
    .right(component)
  }
}

// MARK: - Helpers

public enum _EitherAgent<Left: CactusAgent, Right: CactusAgent>: CactusAgent
where Left.Input == Right.Input, Left.Output == Right.Output {
  case left(Left)
  case right(Right)

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Left.Input>,
    into continuation: CactusAgentStream<Left.Output>.Continuation
  ) async throws {
    switch self {
    case .left(let left):
      try await left.stream(request: request, into: continuation)
    case .right(let right):
      try await right.stream(request: request, into: continuation)
    }
  }
}
