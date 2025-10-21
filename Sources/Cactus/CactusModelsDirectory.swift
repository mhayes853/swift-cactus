import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusModelsDirectory

/// A class that manages a directory to store the models your application uses.
///
/// You can use this class to load models in your application without worrying about managing
/// model storage manually.
/// ```swift
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(for: "qwen3-0.6")
/// let model = try CactusLanguageModel(from: modelURL)
///
/// // ...
/// ```
public final class CactusModelsDirectory: Sendable {
  #if !os(Android)
    /// A shared directory instance.
    ///
    /// This instance stores the models inside the application support directory.
    public static let shared = CactusModelsDirectory(
      baseURL: ._applicationSupportDirectory
        .appendingPathComponent("cactus-models", isDirectory: true)
    )
  #endif

  private struct DownloadTaskEntry {
    let task: CactusLanguageModel.DownloadTask
    let subscription: CactusSubscription
  }

  /// The base `URL` of this directory.
  public let baseURL: URL

  private let downloadTasks = Lock([String: DownloadTaskEntry]())

  private let downloadTask:
    @Sendable (String, URL, URLSessionConfiguration) -> CactusLanguageModel.DownloadTask

  /// Creates a model directory.
  ///
  /// - Parameter baseURL: The `URL` of the directory.
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
  /// Returns a model `URL` for the specified `slug`.
  ///
  /// If this directory doesn't have a model stored with the specified `slug`, then the model is
  /// downloaded and stored in this directory.
  ///
  /// - Parameters:
  ///   - slug: The model slug.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  ///   - onDownloadProgress: A callback for download progress.
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

  /// Returns a ``CactusLanguageModel/DownloadTask`` for the model with the specified `slug`.
  ///
  /// If another download task is in progress, then this method will return the in-progress download task.
  ///
  /// - Parameters:
  ///   - slug: The model slug.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
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
  /// A model stored inside a ``CactusModelsDirectory``.
  public struct StoredModel: Hashable, Sendable {
    /// The slug of the model.
    public let slug: String

    /// The `URL` of the model inside the directory.
    public let url: URL
  }

  /// Returns the stored `URL` for the model with the specified `slug` if one exists.
  ///
  /// - Parameter slug: The model slug.
  public func storedModelURL(for slug: String) -> URL? {
    let destinationURL = self.destinationURL(for: slug)
    var isDirectory = ObjCBool(false)
    let doesExist = FileManager.default.fileExists(
      atPath: destinationURL.relativePath,
      isDirectory: &isDirectory
    )
    return doesExist && isDirectory.boolValue ? destinationURL : nil
  }

  /// Returns an array of all ``StoredModel`` instances in this directory.
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
  /// Removes the locally stored model with the specified `slug`.
  ///
  /// - Parameter slug: The model slug.
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
