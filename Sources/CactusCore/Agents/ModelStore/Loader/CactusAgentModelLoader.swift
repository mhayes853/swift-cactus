public protocol CactusAgentModelLoader {
  func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey

  nonisolated(nonsending) func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel
}
