// MARK: - CactusAgentBuilder

@resultBuilder
public enum CactusAgentBuilder<Input: Sendable, Output: Sendable> {
  public static func buildBlock<A: CactusAgent<Input, Output>>(_ component: A) -> A {
    component
  }

  public static func buildExpression<A: CactusAgent<Input, Output>>(_ expression: A) -> A {
    expression
  }

  @_disfavoredOverload
  public static func buildExpression(
    _ expression: any CactusAgent<Input, Output>
  ) -> AnyAgent<Input, Output> {
    AnyAgent(expression)
  }

  public static func buildLimitedAvailability(
    _ component: some CactusAgent<Input, Output>
  ) -> AnyAgent<Input, Output> {
    AnyAgent(component)
  }

  public static func buildEither<AL: CactusAgent<Input, Output>, AR: CactusAgent<Input, Output>>(
    first component: AL
  ) -> _EitherAgent<AL, AR> {
    .left(component)
  }

  public static func buildEither<AL: CactusAgent<Input, Output>, AR: CactusAgent<Input, Output>>(
    second component: AR
  ) -> _EitherAgent<AL, AR> {
    .right(component)
  }

  public static func buildFinalResult<A: CactusAgent<Input, Output>>(_ component: A) -> A {
    component
  }
}

// MARK: - Helpers

public enum _EitherAgent<Left: CactusAgent, Right: CactusAgent>: CactusAgent
where Left.Input == Right.Input, Left.Output == Right.Output {
  case left(Left)
  case right(Right)

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Left.Input>,
    into continuation: CactusAgentStream<Left.Output>.Continuation
  ) async throws -> CactusAgentStream<Left.Output>.Response {
    switch self {
    case .left(let left):
      try await left.stream(request: request, into: continuation)
    case .right(let right):
      try await right.stream(request: request, into: continuation)
    }
  }
}
