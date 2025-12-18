import IssueReporting

// MARK: - CactusAgentSubstreamPool

final class CactusAgentSubstreamPool: Sendable {
  private struct State {
    var isWorkflowFinished = false
    var substreams = [AnyHashableSendable: any Sendable]()
    var pending = [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]]()
  }

  private let state = Lock(State())

  func append(substream: any Sendable, tag: AnyHashableSendable) {
    self.state.withLock { state in
      if state.substreams[tag] != nil {
        duplicateTag(tag)
      }
      state.substreams[tag] = substream
      let continuations = state.pending.removeValue(forKey: tag) ?? []
      continuations.forEach { $0.resume(returning: substream) }
    }
  }

  func awaitSubstream(for tag: AnyHashableSendable) async throws -> any Sendable {
    try await withUnsafeThrowingContinuation { continuation in
      self.state.withLock { state in
        if let direct = state.substreams[tag] {
          continuation.resume(returning: direct)
        } else if state.isWorkflowFinished {
          continuation.resume(throwing: CactusAgentStreamError.missingSubstream(for: tag))
        } else {
          state.pending[tag, default: []].append(continuation)
        }
      }
    }
  }

  func markWorkflowFinished() {
    self.state.withLock { state in
      state.isWorkflowFinished = true

      let current = state.pending
      state.pending.removeAll()

      for (tag, continuations) in current {
        let error = CactusAgentStreamError.missingSubstream(for: tag)
        continuations.forEach { $0.resume(throwing: error) }
      }
    }
  }
}

// MARK: - Helpers

private func duplicateTag(_ tag: AnyHashableSendable) {
  reportIssue(
    """
    A duplicate tag was detected.

        Tag: \(tag)

    This is generally considered an application logic error, and you should make sure that all \
    tags appended to the `tag` agent modifier are globally unique.

    If you want to scope an agents tags to a local namespace, you can use the `tagNamespace` agent \
    modifier. In doing so, duplicate tags will only be compared against the local namespace.
    """
  )
}
