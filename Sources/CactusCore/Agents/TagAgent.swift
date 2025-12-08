extension CactusAgent {
  public func tag<Tag>(_ tag: Tag, includeOptional: Bool = false) -> _TagAgent<Self, Tag> {
    _TagAgent(base: self, tag: tag, shouldIncludeOptional: includeOptional)
  }
}

public struct _TagAgent<Base: CactusAgent, Tag: Hashable>: CactusAgent {
  let base: Base
  let tag: Tag
  let shouldIncludeOptional: Bool

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws {
    try await self.base.stream(request: request, into: continuation)
  }
}
