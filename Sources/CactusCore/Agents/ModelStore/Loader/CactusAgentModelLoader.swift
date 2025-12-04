public protocol CactusAgentModelLoader {
  nonisolated(nonsending) func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel
}
