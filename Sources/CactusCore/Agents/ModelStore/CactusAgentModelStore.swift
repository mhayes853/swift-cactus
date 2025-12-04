import Foundation

// MARK: - CactusAgentModelRequest

public struct CactusAgentModelRequest {
  public let key: any Hashable & Sendable
  public let loader: any CactusAgentModelLoader
  public let environment: CactusEnvironmentValues

  public init(
    key: any Hashable & Sendable,
    loader: any CactusAgentModelLoader,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.key = key
    self.loader = loader
    self.environment = environment
  }
}

extension CactusAgentModelRequest {
  public static func fromModelURL(
    key: (any Hashable & Sendable)? = nil,
    _ url: URL,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> Self {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    return Self(
      key: key ?? ConfigurationKey(loader: loader),
      loader: loader,
      environment: environment
    )
  }

  public static func fromConfiguration(
    key: (any Hashable & Sendable)? = nil,
    _ configuration: CactusLanguageModel.Configuration,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> Self {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    return Self(
      key: key ?? ConfigurationKey(loader: loader),
      loader: loader,
      environment: environment
    )
  }

  public static func fromDirectory(
    key: (any Hashable & Sendable)? = nil,
    audioSlug: String,
    contextSize: Int = 2048,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> Self {
    let loader = DirectoryModelLoader.fromDirectory(
      audioSlug: audioSlug,
      contextSize: contextSize,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    return Self(
      key: key ?? DirectoryKey(loader: loader),
      loader: loader,
      environment: environment
    )
  }

  public static func fromDirectory(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> Self {
    let loader = DirectoryModelLoader.fromDirectory(
      slug: slug,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    return Self(
      key: key ?? DirectoryKey(loader: loader),
      loader: loader,
      environment: environment
    )
  }
}

// MARK: - CactusModelStore

/// A protocol for accessing and managing `CactusLanguageModel` instances used by agents.
public protocol CactusAgentModelStore {
  nonisolated(nonsending) func prewarmModel(
    request: sending CactusAgentModelRequest
  ) async throws

  nonisolated(nonsending) func withModelAccess<T>(
    request: sending CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T
}

// MARK: - Environment

extension CactusAgent {
  public func modelStore(_ store: any CactusAgentModelStore) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.modelStore, store)
  }
}

extension CactusEnvironmentValues {
  public var modelStore: any CactusAgentModelStore {
    get { self[ModelStoreKey.self] }
    set { self[ModelStoreKey.self] = newValue }
  }

  private enum ModelStoreKey: Key {
    static var defaultValue: any CactusAgentModelStore {
      SessionModelStore()
    }
  }
}
