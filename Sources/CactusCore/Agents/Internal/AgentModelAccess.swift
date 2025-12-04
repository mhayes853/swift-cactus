enum AgentModelAccess {
  case direct(CactusLanguageModel)
  case loaded(key: (any Hashable & Sendable)?, any CactusAgentModelLoader)
}
