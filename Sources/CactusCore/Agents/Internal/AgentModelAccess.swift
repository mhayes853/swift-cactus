enum AgentModelAccess {
  case direct(CactusLanguageModel)
  case loaded(any CactusAgentModelLoader)

  func slug(in environment: CactusEnvironmentValues) -> String {
    switch self {
    case .direct(let model): model.configuration.modelSlug
    case .loaded(let loader): loader.slug(in: environment)
    }
  }

  nonisolated(nonsending) func withModelAccess<T>(
    in environment: CactusEnvironmentValues,
    operation: @Sendable (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T {
    switch self {
    case .direct(let model):
      try operation(model)
    case .loaded(let loader):
      try await environment.modelStore.withModelAccess(
        request: CactusAgentModelRequest(loader, environment: environment),
        perform: operation
      )
    }
  }
}
