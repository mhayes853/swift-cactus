public protocol CactusAgentModelLoader {
  func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey

  func slug(in environment: CactusEnvironmentValues) -> String

  nonisolated(nonsending) func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel
}
