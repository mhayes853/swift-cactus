final class CactusAgentSubstreamPool: Sendable {
  private struct State {
    var substreams = [AnyHashableSendable: any Sendable]()
    var pending = [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]]()
  }

  private let state = Lock(State())

  func append(
    substream: any Sendable,
    tag: AnyHashableSendable
  ) -> [UnsafeContinuation<any Sendable, any Error>] {
    self.state.withLock { state in
      state.substreams[tag] = substream
      return state.pending.removeValue(forKey: tag) ?? []
    }
  }

  func findSubstream(for tag: AnyHashableSendable) -> (any Sendable)? {
    self.state.withLock { state in
      state.substreams[tag]
    }
  }

  func awaitSubstream(for tag: AnyHashableSendable) async throws -> any Sendable {
    if let found = self.findSubstream(for: tag) {
      return found
    }

    return try await withUnsafeThrowingContinuation { continuation in
      let found = self.state.withLock { state -> (any Sendable)? in
        if let direct = state.substreams[tag] {
          return direct
        } else {
          state.pending[tag, default: []].append(continuation)
          return nil
        }
      }

      guard let found else { return }
      continuation.resume(returning: found)
    }
  }

  func failPendingSubstreams() {
    let pending = self.state.withLock {
      state -> [AnyHashableSendable: [UnsafeContinuation<any Sendable, any Error>]] in
      let current = state.pending
      state.pending.removeAll()
      return current
    }

    guard !pending.isEmpty else { return }

    for (tag, continuations) in pending {
      let error = CactusAgentStreamError.missingSubstream(for: tag)
      continuations.forEach { $0.resume(throwing: error) }
    }
  }
}
