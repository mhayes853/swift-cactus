// MARK: - CactusModelStore

/// A protocol for accessing and managing `CactusLanguageModel` instances used by agents.
public protocol CactusAgentModelStore {
  func withModelAccess<T>(
    for request: any CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T
}

// MARK: - CactusModelStoreError

public enum CactusModelStoreError: Error {
  case modelDownloading(CactusLanguageModel.DownloadTask)
  case failedToLoadModel(underlyingError: any Error)
}
