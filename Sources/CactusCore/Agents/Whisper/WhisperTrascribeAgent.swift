import Foundation

public struct WhisperTranscribeAgent: CactusAgent {
  private let access: AgentModelAccess

  public init(_ model: CactusLanguageModel) {
    self.access = .direct(model)
  }

  public init(key: (any Hashable & Sendable)? = nil, url: URL) {
    self.init(key: key, .fromModelURL(url))
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    configuration: CactusLanguageModel.Configuration
  ) {
    self.init(key: key, .fromConfiguration(configuration))
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) {
    self.init(
      key: key,
      .fromDirectory(
        audioSlug: slug,
        contextSize: contextSize,
        directory: directory,
        downloadBehavior: downloadBehavior
      )
    )
  }

  public init(key: (any Hashable & Sendable)? = nil, _ loader: any CactusAgentModelLoader) {
    self.access = .loaded(key: key, loader)
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
