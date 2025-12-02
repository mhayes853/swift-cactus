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
    let downloadConfiguration: URLSessionConfiguration?
  }

  let slug: Slug
  let directory: CactusModelsDirectory
  let contextSize: Int
  let corpusDirectoryURL: URL?
  let downloadConfiguration: URLSessionConfiguration?

  public var id: ID {
    ID(
      slug: self.slug,
      directoryId: ObjectIdentifier(self.directory),
      contextSize: self.contextSize,
      corpusDirectoryURL: self.corpusDirectoryURL,
      downloadConfiguration: self.downloadConfiguration
    )
  }

  public func loadModel(in environment: CactusEnvironmentValues) throws -> CactusLanguageModel {
    if let downloadConfiguration {
      if let model = try self.loadStoredModel() {
        return model
      }
      switch self.slug {
      case .audio(let slug):
        _ = try self.directory.audioModelDownloadTask(
          for: slug,
          configuration: downloadConfiguration
        )
      case .text(let slug):
        _ = try self.directory.modelDownloadTask(for: slug, configuration: downloadConfiguration)
      }
      throw DirectoryModelRequestError.modelDownloading
    } else {
      guard let model = try self.loadStoredModel() else {
        throw DirectoryModelRequestError.modelNotFound
      }
      return model
    }
  }

  private func loadStoredModel() throws -> CactusLanguageModel? {
    guard let url = self.directory.storedModelURL(for: self.slug.text) else {
      return nil
    }
    return try CactusLanguageModel(
      from: url,
      contextSize: self.contextSize,
      modelSlug: self.slug.text,
      corpusDirectoryURL: self.corpusDirectoryURL
    )
  }
}

extension CactusAgentModelRequest where Self == DirectoryModelRequest {
  public static func fromDirectory(
    slug: String,
    directory: CactusModelsDirectory,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    downloadConfiguration: URLSessionConfiguration? = .default
  ) -> Self {
    DirectoryModelRequest(
      slug: .text(slug),
      directory: directory,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      downloadConfiguration: downloadConfiguration
    )
  }

  public static func fromDirectory(
    audioSlug: String,
    directory: CactusModelsDirectory,
    contextSize: Int = 2048,
    downloadConfiguration: URLSessionConfiguration? = .default
  ) -> Self {
    DirectoryModelRequest(
      slug: .audio(audioSlug),
      directory: directory,
      contextSize: contextSize,
      corpusDirectoryURL: nil,
      downloadConfiguration: downloadConfiguration
    )
  }
}

// MARK: - Error

public enum DirectoryModelRequestError: Hashable, Error {
  case modelDownloading
  case modelNotFound
}
