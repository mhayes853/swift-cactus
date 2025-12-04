import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  private let access: AgentModelAccess

  public init(_ model: CactusLanguageModel) {
    self.init(access: .direct(model))
  }

  public init(key: (any Hashable & Sendable)? = nil, url: URL) {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    configuration: CactusLanguageModel.Configuration
  ) {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) {
    let loader = DirectoryModelLoader.fromDirectory(
      audioSlug: slug,
      contextSize: contextSize,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    self.init(key: key ?? DirectoryKey(loader: loader), loader)
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
