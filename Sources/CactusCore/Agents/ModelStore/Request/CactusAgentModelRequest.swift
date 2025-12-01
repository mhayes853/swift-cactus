public protocol CactusAgentModelRequest: Identifiable {
  func loadModel() throws -> CactusLanguageModel
}
