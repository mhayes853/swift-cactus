enum AgentModelAccess: Sendable {
  case direct(LockedBox<CactusLanguageModel>)
  case loaded(any CactusAgentModelLoader)

  static func direct(_ model: sending CactusLanguageModel) -> Self {
    .direct(LockedBox(model))
  }

  func slug(in environment: CactusEnvironmentValues) -> String {
    switch self {
    case .direct(let model): model.inner.withLock { $0.configuration.modelSlug }
    case .loaded(let loader): loader.slug(in: environment)
    }
  }

  nonisolated(nonsending) func withModelAccess<T>(
    in environment: CactusEnvironmentValues,
    operation: @Sendable (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T {
    switch self {
    case .direct(let model):
      try model.inner.withLock { try operation($0) }
    case .loaded(let loader):
      try await environment.modelStore.withModelAccess(
        request: CactusAgentModelRequest(loader, environment: environment),
        perform: operation
      )
    }
  }
}
