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
