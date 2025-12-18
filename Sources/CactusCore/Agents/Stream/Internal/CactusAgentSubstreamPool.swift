import IssueReporting

// MARK: - CactusAgentSubstreamPool

final class CactusAgentSubstreamPool: Sendable {
  struct Key: Hashable, Sendable {
    let tag: AnyHashableSendable
    let namespace: CactusAgentNamespace
  }

  private struct State {
    var isWorkflowFinished = false
    var substreams = [Key: any Sendable]()
    var pending = [Key: [UnsafeContinuation<any Sendable, any Error>]]()
  }

  private let state = Lock(State())

  func append(substream: any Sendable, key: Key) {
    self.state.withLock { state in
      if state.substreams[key] != nil {
        duplicateTag(key)
      }
      state.substreams[key] = substream
      let continuations = state.pending.removeValue(forKey: key) ?? []
      continuations.forEach { $0.resume(returning: substream) }
    }
  }

  func awaitSubstream(for key: Key) async throws -> any Sendable {
    try await withUnsafeThrowingContinuation { continuation in
      self.state.withLock { state in
        if let direct = state.substreams[key] {
          continuation.resume(returning: direct)
        } else if state.isWorkflowFinished {
          continuation.resume(throwing: CactusAgentStreamError.missingSubstream(for: key.tag))
        } else {
          state.pending[key, default: []].append(continuation)
        }
      }
    }
  }

  func markWorkflowFinished() {
    self.state.withLock { state in
      state.isWorkflowFinished = true

      let current = state.pending
      state.pending.removeAll()

      for (key, continuations) in current {
        let error = CactusAgentStreamError.missingSubstream(for: key.tag)
        continuations.forEach { $0.resume(throwing: error) }
      }
    }
  }
}

// MARK: - Helpers

private func duplicateTag(_ key: CactusAgentSubstreamPool.Key) {
  reportIssue(
    """
    A duplicate tag was detected.

        Tag: \(key.tag)
        Namespace: \(key.namespace)

    This is generally considered an application logic error, and you should make sure that all \
    tags appended to the `tag` agent modifier are globally unique.

    If you want to scope an agents tags to a local namespace, you can use the `namespace` agent \
    modifier. In doing so, duplicate tags will only be compared against the local namespace.
    """
  )
}
