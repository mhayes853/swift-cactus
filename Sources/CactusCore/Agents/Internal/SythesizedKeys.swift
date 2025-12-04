import Foundation

// MARK: - ConfigurationKey

struct ConfigurationKey: Hashable, Sendable {
  let configuration: CactusLanguageModel.Configuration
}

extension ConfigurationKey {
  init(loader: ConfigurationModelLoader) {
    self.init(configuration: loader.configuration)
  }
}

// MARK: - DirectoryKey

struct DirectoryKey: Hashable, Sendable {
  let slug: DirectoryModelLoader.Slug
  let contextSize: Int
  let corpusDirectoryURL: URL?
  let directory: ObjectIdentifier?
  let downloadBehavior: CactusAgentModelDownloadBehavior?
}

extension DirectoryKey {
  init(loader: DirectoryModelLoader) {
    self.init(
      slug: loader.slug,
      contextSize: loader.contextSize,
      corpusDirectoryURL: loader.corpusDirectoryURL,
      directory: loader.directory.map(ObjectIdentifier.init),
      downloadBehavior: loader.downloadBehavior
    )
  }
}
