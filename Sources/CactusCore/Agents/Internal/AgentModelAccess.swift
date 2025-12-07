enum AgentModelAccess {
  case direct(CactusLanguageModel)
  case loaded(any CactusAgentModelLoader)
}
