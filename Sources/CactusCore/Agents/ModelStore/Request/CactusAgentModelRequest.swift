public protocol CactusAgentModelRequest: Identifiable {
  func loadModel(in store: any CactusAgentModelStore) throws -> CactusLanguageModel
}
