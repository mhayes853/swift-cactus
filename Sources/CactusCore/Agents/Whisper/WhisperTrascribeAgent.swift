import Foundation

public struct WhisperTranscribeAgent<Loader: CactusAgentModelLoader>: CactusAgent {
  private let loader: Loader

  public init(_ model: CactusLanguageModel) where Loader == ConstantModelLoader {
    self.init(.constant(model))
  }

  public init(url: URL) where Loader == ConfigurationModelLoader {
    self.init(.fromModelURL(url))
  }

  public init(configuration: CactusLanguageModel.Configuration)
  where Loader == ConfigurationModelLoader {
    self.init(.fromConfiguration(configuration))
  }

  public init(
    slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) where Loader == DirectoryModelLoader {
    self.init(
      .fromDirectory(
        audioSlug: slug,
        contextSize: contextSize,
        directory: directory,
        downloadBehavior: downloadBehavior
      )
    )
  }

  public init(_ loader: Loader) {
    self.loader = loader
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<WhisperTranscribePrompt>,
    into continuation: CactusAgentStream<WhisperTranscriptionResponse>.Continuation
  ) async throws {
  }
}
