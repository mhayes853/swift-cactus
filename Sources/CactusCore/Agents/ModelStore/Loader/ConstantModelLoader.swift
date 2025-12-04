public struct NoModelLoader: CactusAgentModelLoader {
  @inlinable
  public nonisolated(nonsending) func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel {
    throw NoModel()
  }

  @usableFromInline
  struct NoModel: Error {
    @usableFromInline
    init() {}
  }
}

extension CactusAgentModelLoader where Self == NoModelLoader {
  public static var noModel: Self {
    NoModelLoader()
  }
}
