import Foundation

public struct ConfigurationModelRequest: CactusAgentModelRequest {
  public struct ID: Hashable, Sendable {
    let configuration: CactusLanguageModel.Configuration
  }

  let configuration: CactusLanguageModel.Configuration

  public var id: ID {
    ID(configuration: self.configuration)
  }

  public func loadModel(in environment: CactusEnvironmentValues) throws -> CactusLanguageModel {
    try CactusLanguageModel(configuration: self.configuration)
  }
}

extension CactusAgentModelRequest where Self == ConfigurationModelRequest {
  public static func fromConfiguration(
    _ configuration: CactusLanguageModel.Configuration
  ) -> Self {
    ConfigurationModelRequest(configuration: configuration)
  }

  public static func fromModelURL(_ url: URL) -> Self {
    .fromConfiguration(CactusLanguageModel.Configuration(modelURL: url))
  }
}
