import class Foundation.FileManager
import struct Foundation.ObjCBool
import struct Foundation.URL

#if canImport(FoundationNetworking)
  import FoundationNetworking
#else
  import class Foundation.URLSessionConfiguration
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
  /// A shared directory instance.
  ///
  /// This instance stores the models inside the application support directory.
  public static let shared = {
    #if os(Android)
      let baseDir = requireAndroidFilesDirectory()
    #else
      let baseDir = URL._applicationSupportDirectory
    #endif
    return CactusModelsDirectory(
      baseURL: baseDir.appendingPathComponent("cactus-models", isDirectory: true)
    )
  }()

  private struct State {
    var downloadTasks = [String: DownloadTaskEntry]()
    var downloadTaskCreator: any DownloadTaskCreator
  }

  private struct DownloadTaskEntry {
    let task: CactusLanguageModel.DownloadTask
    let subscription: CactusSubscription
  }

  /// The base `URL` of this directory.
  public let baseURL: URL

  private let state: Lock<State>

  /// Creates a model directory.
  ///
  /// - Parameter baseURL: The `URL` of the directory.
  public convenience init(baseURL: URL) {
    self.init(baseURL: baseURL, downloadTaskCreator: DefaultDownloadTaskCreator())
  }

  /// Creates a model directory.
  ///
  /// - Parameters:
  ///   - baseURL: The `URL` of the directory.
  ///   - downloadTaskCreator: The ``DownloadTaskCreator`` to use for downloading models.
  public init(baseURL: URL, downloadTaskCreator: sending any DownloadTaskCreator) {
    self.baseURL = baseURL
    self.state = Lock(State(downloadTaskCreator: downloadTaskCreator))
  }
}

// MARK: - DownloadTaskCreator

extension CactusModelsDirectory {
  /// A protocol for creating ``CactusLanguageModel/DownloadTask`` instances for use inside
  /// ``CactusModelsDirectory``.
  ///
  /// ``DefaultDownloadTaskCreator`` will create tasks that download models from the cactus
  /// platform. If you want to create tasks that download models from other sources, you can make a
  /// custom conformance to this protocol to do so.
  /// ```swift
  /// struct MyDownloadTaskCreator: CactusModelsDirectory.DownloadTaskCreator {
  ///   func downloadModelTask(
  ///     slug: String,
  ///     to destination: URL,
  ///     configuration: URLSessionConfiguration
  ///   ) -> CactusLanguageModel.DownloadTask {
  ///     CactusLanguageModel.downloadModelTask(
  ///       from: customDownloadURL(for: slug),
  ///       to: destination,
  ///       configuration: configuration
  ///     )
  ///   }
  ///
  ///   private func customDownloadURL(for slug: String) -> URL {
  ///     // ...
  ///   }
  /// }
  /// ```
  public protocol DownloadTaskCreator {
    /// Creates a ``CactusLanguageModel/DownloadTask``.
    ///
    /// - Parameters:
    ///   - slug: The slug of the model to download.
    ///   - destination: The destination `URL` of the download.
    ///   - configuration: A `URLSessionConfiguration` for the download.
    /// - Returns: A ``CactusLanguageModel/DownloadTask``.
    func downloadModelTask(
      slug: String,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) -> CactusLanguageModel.DownloadTask

    /// Creates a ``CactusLanguageModel/DownloadTask`` for an audio model.
    ///
    /// - Parameters:
    ///   - slug: The slug of the model to download.
    ///   - destination: The destination `URL` of the download.
    ///   - configuration: A `URLSessionConfiguration` for the download.
    /// - Returns: A ``CactusLanguageModel/DownloadTask``.
    func downloadAudioModelTask(
      slug: String,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) -> CactusLanguageModel.DownloadTask
  }

  /// The default ``DownloadTaskCreator``.
  ///
  /// This task creator will download models directly from the cactus platform. Create a custom
  /// conformance to `DownloadTaskCreator` if you wish to download models from elsewhere.
  public struct DefaultDownloadTaskCreator: DownloadTaskCreator, Sendable {
    /// Creates a default download task creator.
    public init() {}
  }
}

extension CactusModelsDirectory.DownloadTaskCreator {
  public func downloadModelTask(
    slug: String,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusLanguageModel.DownloadTask {
    CactusLanguageModel.downloadModelTask(
      slug: slug,
      to: destination,
      configuration: configuration
    )
  }

  public func downloadAudioModelTask(
    slug: String,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusLanguageModel.DownloadTask {
    CactusLanguageModel.downloadAudioModelTask(
      slug: slug,
      to: destination,
      configuration: configuration
    )
  }
}

extension CactusModelsDirectory.DownloadTaskCreator
where Self == CactusModelsDirectory.DefaultDownloadTaskCreator {
  /// The default ``DownloadTaskCreator``.
  ///
  /// This task creator will download models directly from the cactus platform. Create a custom
  /// conformance to `DownloadTaskCreator` if you wish to download models from elsewhere.
  public static var `default`: Self {
    CactusModelsDirectory.DefaultDownloadTaskCreator()
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
    try await self.modelURL(
      for: slug,
      configuration: configuration,
      createTask: self.modelDownloadTask(for:configuration:)
    )
  }

  /// Returns an audio model `URL` for the specified `slug`.
  ///
  /// If this directory doesn't have a model stored with the specified `slug`, then the model is
  /// downloaded and stored in this directory.
  ///
  /// - Parameters:
  ///   - slug: The model slug.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  ///   - onDownloadProgress: A callback for download progress.
  public func audioModelURL(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    try await self.modelURL(
      for: slug,
      configuration: configuration,
      createTask: self.audioModelDownloadTask(for:configuration:)
    )
  }

  private func modelURL(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    createTask: (String, URLSessionConfiguration) throws -> CactusLanguageModel.DownloadTask,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    if let url = self.storedModelURL(for: slug) {
      return url
    }
    let task = try createTask(slug, configuration)
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
    try self.modelDownloadTask(for: slug, configuration: configuration) {
      $3.downloadModelTask(slug: $0, to: $1, configuration: $2)
    }
  }

  /// Returns a ``CactusLanguageModel/DownloadTask`` for an audio model with the specified `slug`.
  ///
  /// If another download task is in progress, then this method will return the in-progress download task.
  ///
  /// - Parameters:
  ///   - slug: The model slug.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  public func audioModelDownloadTask(
    for slug: String,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.modelDownloadTask(for: slug, configuration: configuration) {
      $3.downloadAudioModelTask(slug: $0, to: $1, configuration: $2)
    }
  }

  private func modelDownloadTask(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    createTask: (
      String,
      URL,
      URLSessionConfiguration,
      any DownloadTaskCreator
    ) throws -> CactusLanguageModel.DownloadTask
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.state.withLock { state in
      if let entry = state.downloadTasks[slug] {
        return entry.task
      }
      try self.ensureDirectory()
      let task = try createTask(
        slug,
        self.destinationURL(for: slug),
        configuration,
        state.downloadTaskCreator
      )
      let subscription = task.onProgress { [weak self] progress in
        switch progress {
        case .failure, .success(.finished):
          self?.state.withLock { _ = $0.downloadTasks.removeValue(forKey: slug) }
        default:
          break
        }
      }
      state.downloadTasks[slug] = DownloadTaskEntry(task: task, subscription: subscription)
      return task
    }
  }

  /// All active ``CactusLanguageModel/DownloadTask`` instances currently managed by this
  /// directory.
  public var activeDownloadTasks: [String: CactusLanguageModel.DownloadTask] {
    self.state.withLock { state in state.downloadTasks.mapValues(\.task) }
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
