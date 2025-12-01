// MARK: - CactusModelStore

public protocol CactusModelStore {
  func withModelAccess<T>(
    slug: String,
    in directory: CactusModelsDirectory,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T

  func withModelAccess<T>(
    configuration: CactusLanguageModel.Configuration,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T
}

// MARK: - CactusModelStoreError

public enum CactusModelStoreError: Error {
  case modelDownloading(CactusLanguageModel.DownloadTask)
  case failedToLoadModel(underlyingError: any Error)
}
