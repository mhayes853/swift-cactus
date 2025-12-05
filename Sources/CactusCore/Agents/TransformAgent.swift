// MARK: - TransformInput

extension CactusAgent {
  public func input<Input>(_ input: Self.Input) -> _TransformInputAgent<Self, Input> {
    self.transformInput { _ in input }
  }

  public func transformInput<Input>(
    _ transform: @escaping (Input) throws -> Self.Input
  ) -> _TransformInputAgent<Self, Input> {
    _TransformInputAgent(base: self, transform: transform)
  }
}

public struct _TransformInputAgent<Base: CactusAgent, Input>: CactusAgent {
  let base: Base
  let transform: (Input) throws -> Base.Input

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws {
  }
}

// MARK: - TransformOutput

extension CactusAgent {
  public func transformOutput<Output>(
    _ transform: @escaping (Self.Output) throws -> Output
  ) -> _TransformOutputAgent<Self, Output> {
    _TransformOutputAgent(base: self, transform: transform)
  }
}

public struct _TransformOutputAgent<
  Base: CactusAgent,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  let base: Base
  let transform: (Base.Output) throws -> Output

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}
