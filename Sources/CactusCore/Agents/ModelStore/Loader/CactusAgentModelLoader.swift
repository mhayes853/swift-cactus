public protocol CactusAgentModelLoader {
  func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> CactusLanguageModel
}
