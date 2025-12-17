import Foundation

public struct ConfigurationModelLoader: CactusLanguageModelLoader, CactusAudioModelLoader {
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
  public static func configuration(
    key: (any Hashable & Sendable)? = nil,
    _ configuration: CactusLanguageModel.Configuration
  ) -> Self {
    let modelKey = key.map { CactusAgentModelKey($0) }
    return ConfigurationModelLoader(key: modelKey, configuration: configuration)
  }

  public static func url(key: (any Hashable & Sendable)? = nil, _ url: URL) -> Self {
    .configuration(key: key, CactusLanguageModel.Configuration(modelURL: url))
  }
}
