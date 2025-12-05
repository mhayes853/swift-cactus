import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  private let access: AgentModelAccess

  public init(_ model: CactusLanguageModel) {
    self.init(access: .direct(model))
  }

  public static func fromModelURL(key: (any Hashable & Sendable)? = nil, _ url: URL) -> Self {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader)
  }

  public static func fromConfiguration(
    key: (any Hashable & Sendable)? = nil,
    _ configuration: CactusLanguageModel.Configuration
  ) -> Self {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader)
  }

  public static func fromDirectory(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    let loader = DirectoryModelLoader.fromDirectory(
      audioSlug: slug,
      contextSize: contextSize,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    return Self(key: key ?? DirectoryKey(loader: loader), loader)
  }

  public init(key: (any Hashable & Sendable), _ loader: any CactusAgentModelLoader) {
    self.init(access: .loaded(key: key, loader))
  }

  private init(access: AgentModelAccess) {
    self.access = access
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
