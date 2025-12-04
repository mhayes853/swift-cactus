import Foundation

public struct ConfigurationModelLoader: CactusAgentModelLoader {
  let configuration: CactusLanguageModel.Configuration

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) throws -> sending CactusLanguageModel {
    try CactusLanguageModel(configuration: self.configuration)
  }
}

extension CactusAgentModelLoader where Self == ConfigurationModelLoader {
  public static func fromConfiguration(
    _ configuration: CactusLanguageModel.Configuration
  ) -> Self {
    ConfigurationModelLoader(configuration: configuration)
  }

  public static func fromModelURL(_ url: URL) -> Self {
    .fromConfiguration(CactusLanguageModel.Configuration(modelURL: url))
  }
}
