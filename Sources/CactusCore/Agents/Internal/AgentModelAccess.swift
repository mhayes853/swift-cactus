enum AgentModelAccess {
  case direct(CactusLanguageModel)
  case loaded(any CactusAgentModelLoader)

  func slug(in environment: CactusEnvironmentValues) -> String {
    switch self {
    case .direct(let model): model.configuration.modelSlug
    case .loaded(let loader): loader.slug(in: environment)
    }
  }
}
