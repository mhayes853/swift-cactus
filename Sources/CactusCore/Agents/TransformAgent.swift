// MARK: - TransformInput

public struct TransformInput<Input: Sendable, Child: CactusAgent>: CactusAgent {
  @usableFromInline
  let child: Child

  @usableFromInline
  let transform: (Input) async throws -> Child.Input

  @inlinable
  public init(
    _ transform: @escaping (Input) async throws -> Child.Input,
    @CactusAgentBuilder<Child.Input, Child.Output> agent: () -> Child
  ) {
    self.child = agent()
    self.transform = transform
  }

  @inlinable
  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Child.Output>.Continuation
  ) async throws -> CactusAgentStream<Child.Output>.Response {
    let transformedInput = try await self.transform(request.input)
    let childRequest = CactusAgentRequest(
      input: transformedInput,
      environment: request.environment
    )
    return try await self.child.stream(request: childRequest, into: continuation)
  }
}

// MARK: - TransformOutput

extension CactusAgent where Input: Sendable {
  public func inputAsOutput() -> _TransformOutputAgent<Self, Input> where Input: Sendable {
    self.transformOutput { $1 }
  }

  public func transformOutput<Output>(
    _ transform: @escaping @Sendable (Self.Output) throws -> Output
  ) -> _TransformOutputAgent<Self, Output> {
    self.transformOutput { output, _ in try transform(output) }
  }

  public func transformOutput<Output>(
    _ transform: @escaping @Sendable (Self.Output, Input) throws -> Output
  ) -> _TransformOutputAgent<Self, Output> {
    _TransformOutputAgent(base: self, transform: transform)
  }
}

public struct _TransformOutputAgent<Base: CactusAgent, Output: Sendable>: CactusAgent
where Base.Input: Sendable {
  let base: Base
  let transform: @Sendable (Base.Output, Base.Input) throws -> Output

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    let baseResponse = try await self.base.stream(
      request: request,
      into: continuation._unsafelyCastOutput()
    )
    let transform = self.transform
    return try baseResponse.map { try transform($0, request.input) }
  }
}
