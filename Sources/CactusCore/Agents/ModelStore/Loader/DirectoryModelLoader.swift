import Foundation

// MARK: - DirectoryModelRequest

public struct DirectoryModelLoader: CactusAgentModelLoader {
  enum Slug: Hashable, Sendable {
    case audio(String)
    case text(String)

    var text: String {
      switch self {
      case .audio(let text): text
      case .text(let text): text
      }
    }
  }

  let key: CactusAgentModelKey?
  let slug: Slug
  let contextSize: Int
  let corpusDirectoryURL: URL?
  let directory: CactusModelsDirectory?
  let downloadBehavior: CactusAgentModelDownloadBehavior?

  public func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey {
    self.key
      ?? CactusAgentModelKey(
        Key(
          slug: self.slug,
          contextSize: self.contextSize,
          corpusDirectoryURL: self.corpusDirectoryURL,
          directory: ObjectIdentifier(self.directory ?? environment.modelsDirectory)
        )
      )
  }

  private struct Key: Hashable {
    let slug: Slug
    let contextSize: Int
    let corpusDirectoryURL: URL?
    let directory: ObjectIdentifier
  }

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel {
    if let model = try self.loadStoredModel(in: environment) {
      return model
    }
    let directory = self.directory ?? environment.modelsDirectory
    switch self.downloadBehavior ?? environment.modelDownloadBehavior {
    case .noDownloading:
      throw DirectoryModelLoaderError.modelNotFound

    case .beginDownload(let configuration):
      let task =
        switch self.slug {
        case .audio(let slug):
          try directory.audioModelDownloadTask(
            for: slug,
            configuration: configuration
          )
        case .text(let slug):
          try directory.modelDownloadTask(for: slug, configuration: configuration)
        }
      task.resume()
      throw DirectoryModelLoaderError.modelDownloading

    case .waitForDownload(let configuration):
      switch self.slug {
      case .audio(let slug):
        let url = try await directory.audioModelURL(for: slug, configuration: configuration)
        return try CactusLanguageModel(configuration: self.modelConfiguration(url: url))
      case .text(let slug):
        let url = try await directory.modelURL(for: slug, configuration: configuration)
        return try CactusLanguageModel(configuration: self.modelConfiguration(url: url))
      }
    }
  }

  private func loadStoredModel(
    in environment: CactusEnvironmentValues
  ) throws -> sending CactusLanguageModel? {
    let directory = self.directory ?? environment.modelsDirectory
    guard let url = directory.storedModelURL(for: self.slug.text) else {
      return nil
    }
    return try CactusLanguageModel(
      configuration: self.modelConfiguration(url: url)
    )
  }

  private func modelConfiguration(url: URL) -> CactusLanguageModel.Configuration {
    CactusLanguageModel.Configuration(
      modelURL: url,
      contextSize: self.contextSize,
      modelSlug: self.slug.text,
      corpusDirectoryURL: self.corpusDirectoryURL
    )
  }
}

extension CactusAgentModelLoader where Self == DirectoryModelLoader {
  public static func fromDirectory(
    key: CactusAgentModelKey? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryModelLoader(
      key: key,
      slug: .text(slug),
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
  }

  public static func fromDirectory(
    key: CactusAgentModelKey? = nil,
    audioSlug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryModelLoader(
      key: key,
      slug: .audio(audioSlug),
      contextSize: contextSize,
      corpusDirectoryURL: nil,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
  }
}

// MARK: - Error

public enum DirectoryModelLoaderError: Hashable, Error {
  case modelDownloading
  case modelNotFound
}
