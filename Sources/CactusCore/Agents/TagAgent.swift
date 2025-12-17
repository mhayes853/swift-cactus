extension CactusAgent {
  public func tag<Tag>(_ tag: Tag) -> _TagAgent<Self, Tag> {
    _TagAgent(base: self, tag: tag)
  }
}

public struct _TagAgent<Base: CactusAgent, Tag: Hashable & Sendable>: CactusAgent {
  let base: Base
  let tag: Tag

  public nonisolated(nonsending) func primitiveStream(
    request: CactusAgentRequest<Base.Input>,
    into continuation: CactusAgentStream<Base.Output>.Continuation
  ) async throws -> CactusAgentStream<Base.Output>.Response {
    let transfer = UnsafeTransfer(value: request)
    let baseStream = CactusAgentStream { baseContinuation in
      try await self.base.stream(request: transfer.value, into: baseContinuation)
    }
    continuation.append(substream: baseStream, tag: self.tag)
    return try await baseStream.streamResponse()
  }
}
