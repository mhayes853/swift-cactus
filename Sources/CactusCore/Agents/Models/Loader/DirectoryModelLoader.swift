import Foundation

// MARK: - Language Directory Loader

public struct DirectoryLanguageModelLoader: CactusLanguageModelLoader {
  let key: CactusAgentModelKey?
  let slug: String
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

  public func slug(in environment: CactusEnvironmentValues) -> String {
    self.slug
  }

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel {
    try await loadDirectoryModel(
      slug: self.slug,
      directory: self.directory,
      downloadBehavior: self.downloadBehavior,
      environment: environment,
      configuration: { self.modelConfiguration(url: $0) },
      downloadTask: { try $0.modelDownloadTask(for: $1, configuration: $2) },
      modelURL: { try await $0.modelURL(for: $1, configuration: $2) }
    )
  }

  private struct Key: Hashable {
    let slug: String
    let contextSize: Int
    let corpusDirectoryURL: URL?
    let directory: ObjectIdentifier
  }

  private func modelConfiguration(url: URL) -> CactusLanguageModel.Configuration {
    CactusLanguageModel.Configuration(
      modelURL: url,
      contextSize: self.contextSize,
      modelSlug: self.slug,
      corpusDirectoryURL: self.corpusDirectoryURL
    )
  }
}

extension CactusLanguageModelLoader where Self == DirectoryLanguageModelLoader {
  public static func slug(
    key: CactusAgentModelKey? = nil,
    _ slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryLanguageModelLoader(
      key: key,
      slug: slug,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
  }
}

// MARK: - Audio Directory Loader

public struct DirectoryAudioModelLoader: CactusAudioModelLoader {
  let key: CactusAgentModelKey?
  let slug: String
  let contextSize: Int
  let directory: CactusModelsDirectory?
  let downloadBehavior: CactusAgentModelDownloadBehavior?

  public func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey {
    self.key
      ?? CactusAgentModelKey(
        Key(
          slug: self.slug,
          contextSize: self.contextSize,
          directory: ObjectIdentifier(self.directory ?? environment.modelsDirectory)
        )
      )
  }

  public func slug(in environment: CactusEnvironmentValues) -> String {
    self.slug
  }

  public func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel {
    try await loadDirectoryModel(
      slug: self.slug,
      directory: self.directory,
      downloadBehavior: self.downloadBehavior,
      environment: environment,
      configuration: { self.modelConfiguration(url: $0) },
      downloadTask: { try $0.audioModelDownloadTask(for: $1, configuration: $2) },
      modelURL: { try await $0.audioModelURL(for: $1, configuration: $2) }
    )
  }

  private struct Key: Hashable {
    let slug: String
    let contextSize: Int
    let directory: ObjectIdentifier
  }

  private func modelConfiguration(url: URL) -> CactusLanguageModel.Configuration {
    CactusLanguageModel.Configuration(
      modelURL: url,
      contextSize: self.contextSize,
      modelSlug: self.slug,
      corpusDirectoryURL: nil
    )
  }
}

extension CactusAudioModelLoader where Self == DirectoryAudioModelLoader {
  public static func slug(
    key: CactusAgentModelKey? = nil,
    _ slug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryAudioModelLoader(
      key: key,
      slug: slug,
      contextSize: contextSize,
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

// MARK: - Helpers

private func loadDirectoryModel(
  slug: String,
  directory: CactusModelsDirectory?,
  downloadBehavior: CactusAgentModelDownloadBehavior?,
  environment: CactusEnvironmentValues,
  configuration: (URL) -> CactusLanguageModel.Configuration,
  downloadTask: (CactusModelsDirectory, String, URLSessionConfiguration)
    throws -> CactusLanguageModel.DownloadTask,
  modelURL: (CactusModelsDirectory, String, URLSessionConfiguration) async throws -> URL
) async throws -> sending CactusLanguageModel {
  let directory = directory ?? environment.modelsDirectory
  if let url = directory.storedModelURL(for: slug) {
    return try CactusLanguageModel(configuration: configuration(url))
  }

  switch downloadBehavior ?? environment.modelDownloadBehavior {
  case .noDownloading:
    throw DirectoryModelLoaderError.modelNotFound

  case .beginDownload(let downloadConfiguration):
    let task = try downloadTask(directory, slug, downloadConfiguration)
    task.resume()
    throw DirectoryModelLoaderError.modelDownloading

  case .waitForDownload(let downloadConfiguration):
    let url = try await modelURL(directory, slug, downloadConfiguration)
    return try CactusLanguageModel(configuration: configuration(url))
  }
}
