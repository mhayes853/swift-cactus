public protocol CactusAgentModelRequest: Identifiable {
  func loadModel(in environment: CactusEnvironmentValues) throws -> CactusLanguageModel
}
