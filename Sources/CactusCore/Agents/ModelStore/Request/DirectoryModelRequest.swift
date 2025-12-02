import Foundation

// MARK: - DirectoryModelRequest

public struct DirectoryModelRequest: CactusAgentModelRequest {
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

  public struct ID: Hashable, Sendable {
    let slug: Slug
    let directoryId: ObjectIdentifier
    let contextSize: Int
    let corpusDirectoryURL: URL?
  }

  let slug: Slug
  let contextSize: Int
  let corpusDirectoryURL: URL?
  let directory: CactusModelsDirectory?
  let downloadBehavior: CactusAgentModelDownloadBehavior?

  public func id(in environment: CactusEnvironmentValues) -> ID {
    ID(
      slug: self.slug,
      directoryId: ObjectIdentifier(self.directory ?? environment.modelsDirectory),
      contextSize: self.contextSize,
      corpusDirectoryURL: self.corpusDirectoryURL
    )
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
      throw DirectoryModelRequestError.modelNotFound

    case .beginDownload(let configuration):
      switch self.slug {
      case .audio(let slug):
        _ = try directory.audioModelDownloadTask(
          for: slug,
          configuration: configuration
        )
      case .text(let slug):
        _ = try directory.modelDownloadTask(for: slug, configuration: configuration)
      }
      throw DirectoryModelRequestError.modelDownloading

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

extension CactusAgentModelRequest where Self == DirectoryModelRequest {
  public static func fromDirectory(
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryModelRequest(
      slug: .text(slug),
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
  }

  public static func fromDirectory(
    audioSlug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil
  ) -> Self {
    DirectoryModelRequest(
      slug: .audio(audioSlug),
      contextSize: contextSize,
      corpusDirectoryURL: nil,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
  }
}

// MARK: - Error

public enum DirectoryModelRequestError: Hashable, Error {
  case modelDownloading
  case modelNotFound
}
