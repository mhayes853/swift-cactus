import Cactus

// MARK: - NeverAgent

struct NeverAgent: CactusAgent {
  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
    Run { _ in
      try await Task.never()
      return ""
    }
  }
}

// MARK: - PassthroughAgent

struct PassthroughAgent: CactusAgent {
  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
    Run { $0 }
  }
}

// MARK: - BlockingAgent

actor ResponseGate {
  private var continuations = [CheckedContinuation<Void, any Error>]()

  func wait() async throws {
    let continuation = Lock<CheckedContinuation<Void, any Error>?>(nil)
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { c in
        continuation.withLock { $0 = c }
        self.continuations.append(c)
      }
    } onCancel: {
      continuation.withLock { $0?.resume(throwing: CancellationError()) }
    }
  }

  func openNext() {
    guard !self.continuations.isEmpty else { return }
    self.continuations.removeFirst().resume()
  }
}

struct BlockingAgent: CactusAgent {
  let gate: ResponseGate

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<String, String> {
    Stream { request, _ in
      try await gate.wait()
      return .finalOutput(request.input)
    }
  }
}
