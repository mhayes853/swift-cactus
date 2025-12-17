final class CactusAgentSubstreamPool: Sendable {
  private struct State {
    var isWorkflowFinished = false
    var substreams = [AnyHashableSendable: any Sendable]()
    var pending = [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]]()
  }

  private let state = Lock(State())

  func append(substream: any Sendable, tag: AnyHashableSendable) {
    self.state.withLock { state in
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
