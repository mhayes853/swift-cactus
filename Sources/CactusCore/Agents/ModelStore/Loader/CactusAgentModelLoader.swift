public protocol CactusAgentModelLoader: Sendable {
  func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey

  func slug(in environment: CactusEnvironmentValues) -> String

  func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel
}
