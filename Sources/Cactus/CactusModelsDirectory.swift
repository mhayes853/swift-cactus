import Foundation

#if canImport(FoundatioNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusModelsDirectory

public final class CactusModelsDirectory: Sendable {
  #if !os(Android)
    public static let shared = CactusModelsDirectory(
      baseURL: ._applicationSupportDirectory
        .appendingPathComponent("cactus-models", isDirectory: true)
    )
  #endif

  private struct DownloadTaskEntry {
    let task: CactusLanguageModel.DownloadTask
    let subscription: CactusSubscription
  }

  public let baseURL: URL
  private let downloadTasks = Lock([String: DownloadTaskEntry]())

  private let downloadTask:
    @Sendable (String, URL, URLSessionConfiguration) -> CactusLanguageModel.DownloadTask

  public convenience init(baseURL: URL) {
    self.init(baseURL: baseURL) { slug, dst, configuation in
      CactusLanguageModel.downloadModelTask(slug: slug, to: dst, configuration: configuation)
    }
  }

  package init(
    baseURL: URL,
    downloadTask:
      @escaping @Sendable (String, URL, URLSessionConfiguration) -> CactusLanguageModel.DownloadTask
  ) {
    self.baseURL = baseURL
    self.downloadTask = downloadTask
  }
}

// MARK: - Model Loading

extension CactusModelsDirectory {
  public func modelURL(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    if let url = self.storedModelURL(for: slug) {
      return url
    }
    let task = try self.modelDownloadTask(for: slug, configuration: configuration)
    task.resume()
    let subscription = task.onProgress(onDownloadProgress)
    defer { subscription.cancel() }
    return try await withTaskCancellationHandler {
      try await task.waitForCompletion()
    } onCancel: {
      task.cancel()
    }
  }

  public func modelDownloadTask(
    for slug: String,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusLanguageModel.DownloadTask {
    if let task = self.downloadTasks.withLock({ $0[slug]?.task }) {
      return task
    }
    try self.ensureDirectory()
    let task = self.downloadTask(slug, self.destinationURL(for: slug), configuration)
    let subscription = task.onProgress { [weak self] progress in
      switch progress {
      case .failure, .success(.finished):
        self?.downloadTasks.withLock { _ = $0.removeValue(forKey: slug) }
      default:
        break
      }
    }
    self.downloadTasks.withLock {
      $0[slug] = DownloadTaskEntry(task: task, subscription: subscription)
    }
    return task
  }
}

// MARK: - Stored Models

extension CactusModelsDirectory {
  public struct StoredModel: Hashable, Sendable {
    public let slug: String
    public let url: URL
  }

  public func storedModelURL(for slug: String) -> URL? {
    let destinationURL = self.destinationURL(for: slug)
    var isDirectory = ObjCBool(false)
    FileManager.default.fileExists(atPath: destinationURL.relativePath, isDirectory: &isDirectory)
    return isDirectory.boolValue ? destinationURL : nil
  }

  public func storedModels() -> [StoredModel] {
    let models = try? FileManager.default
      .contentsOfDirectory(at: self.baseURL, includingPropertiesForKeys: [.isDirectoryKey])
      .map {
        StoredModel(slug: $0.lastPathComponent, url: self.destinationURL(for: $0.lastPathComponent))
      }
    return models ?? []
  }
}

// MARK: - Model Removing

extension CactusModelsDirectory {
  public func removeModel(with slug: String) throws {
    try FileManager.default.removeItem(at: self.destinationURL(for: slug))
  }
}

// MARK: - Helpers

extension CactusModelsDirectory {
  private func destinationURL(for slug: String) -> URL {
    self.baseURL.appendingPathComponent(slug, isDirectory: true)
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
  }
}
