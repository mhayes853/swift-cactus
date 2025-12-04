import Foundation

public struct WhisperTranscribeAgent<Loader: CactusAgentModelLoader>: CactusAgent {
  private let loader: Loader
  private let key: AnyHashable?

  public init(key: AnyHashable? = nil, _ model: CactusLanguageModel)
  where Loader == NoModelLoader {
    self.init(key: key, .noModel)
  }

  public init(key: AnyHashable? = nil, url: URL) where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromModelURL(url))
  }

  public init(key: AnyHashable? = nil, configuration: CactusLanguageModel.Configuration)
  where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromConfiguration(configuration))
  }

  public init(
    key: AnyHashable? = nil,
    slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) where Loader == DirectoryModelLoader {
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

  public init(key: AnyHashable? = nil, _ loader: Loader) {
    self.key = key
    self.loader = loader
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
