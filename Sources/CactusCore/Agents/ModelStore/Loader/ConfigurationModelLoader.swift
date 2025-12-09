import Foundation

public struct ConfigurationModelLoader: CactusAgentModelLoader {
  let key: CactusAgentModelKey?
  let configuration: CactusLanguageModel.Configuration

  public func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey {
    self.key ?? CactusAgentModelKey(Key(configuration: self.configuration))
  }

  public func slug(in environment: CactusEnvironmentValues) -> String {
    self.configuration.modelSlug
  }

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) throws -> sending CactusLanguageModel {
    try CactusLanguageModel(configuration: self.configuration)
  }

  private struct Key: Hashable {
    let configuration: CactusLanguageModel.Configuration
  }
}

extension CactusAgentModelLoader where Self == ConfigurationModelLoader {
  public static func fromConfiguration(
    key: CactusAgentModelKey? = nil,
    _ configuration: CactusLanguageModel.Configuration
  ) -> Self {
    ConfigurationModelLoader(key: key, configuration: configuration)
  }

  public static func fromModelURL(key: CactusAgentModelKey? = nil, _ url: URL) -> Self {
    .fromConfiguration(CactusLanguageModel.Configuration(modelURL: url))
  }
}
