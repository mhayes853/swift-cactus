import Foundation

// MARK: - CactusAgentModelDownloadBehavior

public enum CactusAgentModelDownloadBehavior: Sendable {
  case noDownloading
  case beginDownload(URLSessionConfiguration)
  case waitForDownload(URLSessionConfiguration)
}

extension CactusAgent {
  public func modelDownloadBehavior(
    _ behavior: CactusAgentModelDownloadBehavior
  ) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.modelDownloadBehavior, behavior)
  }
}

extension CactusEnvironmentValues {
  public var modelDownloadBehavior: CactusAgentModelDownloadBehavior {
    get { self[ModelDownloadBehaviorKey.self] }
    set { self[ModelDownloadBehaviorKey.self] = newValue }
  }

  private enum ModelDownloadBehaviorKey: Key {
    static let defaultValue = CactusAgentModelDownloadBehavior.beginDownload(.default)
  }
}

// MARK: - ModelsDirectory

extension CactusAgent {
  public func modelsDirectory(
    _ directory: CactusModelsDirectory
  ) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.modelsDirectory, directory)
  }
}

extension CactusEnvironmentValues {
  public var modelsDirectory: CactusModelsDirectory {
    get { self[ModelsDirectoryKey.self] }
    set { self[ModelsDirectoryKey.self] = newValue }
  }

  private enum ModelsDirectoryKey: Key {
    static let defaultValue = CactusModelsDirectory.shared
  }
}
