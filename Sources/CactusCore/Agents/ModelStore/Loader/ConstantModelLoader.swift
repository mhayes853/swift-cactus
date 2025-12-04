public struct ConstantModelLoader: CactusAgentModelLoader {
  let model: CactusLanguageModel

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> CactusLanguageModel {
    self.model
  }
}

extension CactusAgentModelLoader where Self == ConstantModelLoader {
  public static func constant(_ model: CactusLanguageModel) -> Self {
    ConstantModelLoader(model: model)
  }
}
