extension CactusAgent {
  public func tag<Tag>(_ tag: Tag) -> _TagAgent<Self, Tag> {
    _TagAgent(base: self, tag: tag)
  }
}

public struct _TagAgent<Base: CactusAgent, Tag: Hashable & Sendable>: CactusAgent {
  let base: Base
  let tag: Tag

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    try await self.base.stream(request: request, into: continuation)
  }
}
