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
/// let request = CactusLanguageModel.PlatformDownloadRequest.qwen3_0_6b()
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(for: request)
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
    var downloadTasks = [CactusLanguageModel.PlatformDownloadRequest: DownloadTaskEntry]()
    var downloadTaskCreator: any DownloadTaskCreator
  }

  private struct DownloadTaskEntry {
    let task: CactusLanguageModel.DownloadTask
    let subscription: CactusSubscription
  }

  /// The base `URL` of this directory.
  public let baseURL: URL

  private let state: Lock<State>

  private let observationRegistrar = _ObservationRegistrar()

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
  ///     request: CactusLanguageModel.PlatformDownloadRequest,
  ///     to destination: URL,
  ///     configuration: URLSessionConfiguration
  ///   ) -> CactusLanguageModel.DownloadTask {
  ///     CactusLanguageModel.downloadModelTask(
  ///       from: customDownloadURL(for: request),
  ///       to: destination,
  ///       configuration: configuration
  ///     )
  ///   }
  ///
  ///   private func customDownloadURL(for request: CactusLanguageModel.PlatformDownloadRequest) -> URL {
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
    @available(*, deprecated, message: "Use `downloadModelTask(request:to:configuration:)` instead.")
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
    @available(*, deprecated, message: "Use `downloadModelTask(request:to:configuration:)` instead.")
    func downloadAudioModelTask(
      slug: String,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) -> CactusLanguageModel.DownloadTask

    /// Creates a ``CactusLanguageModel/DownloadTask``.
    ///
    /// - Parameters:
    ///   - request: The platform download request to use.
    ///   - destination: The destination `URL` of the download.
    ///   - configuration: A `URLSessionConfiguration` for the download.
    /// - Returns: A ``CactusLanguageModel/DownloadTask``.
    func downloadModelTask(
      request: CactusLanguageModel.PlatformDownloadRequest,
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
    request: CactusLanguageModel.PlatformDownloadRequest,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusLanguageModel.DownloadTask {
    CactusLanguageModel.downloadModelTask(
      request: request,
      to: destination,
      configuration: configuration
    )
  }

  @available(*, deprecated, message: "Use `downloadModelTask(request:to:configuration:)` instead.")
  public func downloadModelTask(
    slug: String,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusLanguageModel.DownloadTask {
    downloadModelTask(
      request: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
      to: destination,
      configuration: configuration
    )
  }

  @available(*, deprecated, message: "Use `downloadModelTask(request:to:configuration:)` instead.")
  public func downloadAudioModelTask(
    slug: String,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusLanguageModel.DownloadTask {
    downloadModelTask(
      request: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
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
  @available(*, deprecated, message: "Use `modelURL(for:configuration:onDownloadProgress:)` with a `PlatformDownloadRequest` instead.")
  public func modelURL(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    try await self.modelURL(
      for: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
      configuration: configuration,
      onDownloadProgress: onDownloadProgress
    )
  }

  /// Returns a model `URL` for the specified download request.
  ///
  /// If this directory doesn't have a model stored with the specified request, then the model is
  /// downloaded and stored in this directory.
  ///
  /// - Parameters:
  ///   - request: The platform download request for the model.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  ///   - onDownloadProgress: A callback for download progress.
  public func modelURL(
    for request: CactusLanguageModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    try await self.modelURL(
      for: request,
      configuration: configuration,
      createTask: self.modelDownloadTask(for:configuration:),
      onDownloadProgress: onDownloadProgress
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
  @available(*, deprecated, message: "Use `modelURL(for:configuration:onDownloadProgress:)` with a `PlatformDownloadRequest` instead.")
  public func audioModelURL(
    for slug: String,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    try await self.modelURL(
      for: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
      configuration: configuration,
      onDownloadProgress: onDownloadProgress
    )
  }

  private func modelURL(
    for request: CactusLanguageModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default,
    createTask: (
      CactusLanguageModel.PlatformDownloadRequest,
      URLSessionConfiguration
    ) throws -> CactusLanguageModel.DownloadTask,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    if let url = self.storedModelURL(for: request) {
      return url
    }
    let task = try createTask(request, configuration)
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
  @available(*, deprecated, message: "Use `modelDownloadTask(for:configuration:)` with a `PlatformDownloadRequest` instead.")
  public func modelDownloadTask(
    for slug: String,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.modelDownloadTask(
      for: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
      configuration: configuration
    )
  }

  /// Returns a ``CactusLanguageModel/DownloadTask`` for the model with the specified request.
  ///
  /// If another download task is in progress, then this method will return the in-progress download task.
  ///
  /// - Parameters:
  ///   - request: The platform download request for the model.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  public func modelDownloadTask(
    for request: CactusLanguageModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.modelDownloadTask(for: request, configuration: configuration) {
      $3.downloadModelTask(request: $0, to: $1, configuration: $2)
    }
  }

  /// Returns a ``CactusLanguageModel/DownloadTask`` for an audio model with the specified `slug`.
  ///
  /// If another download task is in progress, then this method will return the in-progress download task.
  ///
  /// - Parameters:
  ///   - slug: The model slug.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  @available(*, deprecated, message: "Use `modelDownloadTask(for:configuration:)` with a `PlatformDownloadRequest` instead.")
  public func audioModelDownloadTask(
    for slug: String,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.modelDownloadTask(
      for: CactusLanguageModel.PlatformDownloadRequest(slug: slug),
      configuration: configuration
    )
  }

  private func modelDownloadTask(
    for request: CactusLanguageModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default,
    createTask: (
      CactusLanguageModel.PlatformDownloadRequest,
      URL,
      URLSessionConfiguration,
      any DownloadTaskCreator
    ) throws -> CactusLanguageModel.DownloadTask
  ) throws -> CactusLanguageModel.DownloadTask {
    try self.state.withLock { state in
      if let entry = state.downloadTasks[request] {
        return entry.task
      }
      try self.ensureDirectory()
      let task = try createTask(
        request,
        self.destinationURL(for: request),
        configuration,
        state.downloadTaskCreator
      )
      let subscription = task.onProgress { [weak self] progress in
        switch progress {
        case .failure, .success(.finished):
          guard let self else { return }
          self.state
            .withLock { state in
              self.observationRegistrar.withMutation(of: self, keyPath: \.activeDownloadTasks) {
                _ = state.downloadTasks.removeValue(forKey: request)
              }
            }
        default:
          break
        }
      }
      self.observationRegistrar.withMutation(of: self, keyPath: \.activeDownloadTasks) {
        state.downloadTasks[request] = DownloadTaskEntry(task: task, subscription: subscription)
      }
      return task
    }
  }

  /// All active ``CactusLanguageModel/DownloadTask`` instances currently managed by this
  /// directory.
  public var activeDownloadTasks: [CactusLanguageModel.PlatformDownloadRequest: CactusLanguageModel.DownloadTask] {
    self.observationRegistrar.access(self, keyPath: \.activeDownloadTasks)
    return self.state.withLock { state in state.downloadTasks.mapValues(\.task) }
  }

  /// All active ``CactusLanguageModel/DownloadTask`` instances currently managed by this
  /// directory, keyed by model slug.
  @available(*, deprecated, message: "Use `activeDownloadTasks` keyed by `PlatformDownloadRequest` instead.")
  public var activeDownloadTasksBySlug: [String: CactusLanguageModel.DownloadTask] {
    Dictionary(
      uniqueKeysWithValues: self.activeDownloadTasks.map { ($0.key.slug, $0.value) }
    )
  }
}

// MARK: - Stored Models

extension CactusModelsDirectory {
  /// A model stored inside a ``CactusModelsDirectory``.
  public struct StoredModel: Hashable, Sendable {
    /// The platform download request used for this model.
    public let request: CactusLanguageModel.PlatformDownloadRequest

    /// The `URL` of the model inside the directory.
    public let url: URL

    /// The slug of the model.
    @available(*, deprecated, message: "Use `request.slug` instead.")
    public var slug: String {
      self.request.slug
    }
  }

  /// Returns the stored `URL` for the model with the specified `slug` if one exists.
  ///
  /// - Parameter slug: The model slug.
  @available(*, deprecated, message: "Use `storedModelURL(for:)` with a `PlatformDownloadRequest` instead.")
  public func storedModelURL(for slug: String) -> URL? {
    self.storedModelURL(for: CactusLanguageModel.PlatformDownloadRequest(slug: slug))
  }

  /// Returns the stored `URL` for the model with the specified request if one exists.
  ///
  /// - Parameter request: The platform download request for the model.
  public func storedModelURL(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) -> URL? {
    let destinationURL = self.destinationURL(for: request)
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
        let request = self.request(fromDirectoryName: $0.lastPathComponent)
          ?? CactusLanguageModel.PlatformDownloadRequest(slug: $0.lastPathComponent)
        return StoredModel(request: request, url: $0)
      }
    return models ?? []
  }
}

// MARK: - Model Removing

extension CactusModelsDirectory {
  /// Removes the locally stored model with the specified `slug`.
  ///
  /// - Parameter slug: The model slug.
  @available(*, deprecated, message: "Use `removeModel(with:)` with a `PlatformDownloadRequest` instead.")
  public func removeModel(with slug: String) throws {
    try removeModel(with: CactusLanguageModel.PlatformDownloadRequest(slug: slug))
  }

  /// Removes the locally stored model with the specified request.
  ///
  /// - Parameter request: The platform download request for the model.
  public func removeModel(
    with request: CactusLanguageModel.PlatformDownloadRequest
  ) throws {
    try FileManager.default.removeItem(at: self.destinationURL(for: request))
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModelsDirectory: _Observable {
}

// MARK: - Helpers

extension CactusModelsDirectory {
  private func destinationURL(for slug: String) -> URL {
    self.baseURL.appendingPathComponent(slug, isDirectory: true)
  }

  private func destinationURL(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) -> URL {
    self.baseURL.appendingPathComponent(self.directoryName(for: request), isDirectory: true)
  }

  private func directoryName(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) -> String {
    [
      request.slug,
      request.quantization.rawValue,
      request.version.rawValue,
      request.pro?.rawValue,
    ]
    .compactMap { $0?.lowercased() }
    .joined(separator: "--")
  }

  private func request(fromDirectoryName name: String) -> CactusLanguageModel.PlatformDownloadRequest? {
    let parts = name.components(separatedBy: "--")
    guard parts.count >= 3 else { return nil }
    let slug = parts[0]
    let quantization = CactusLanguageModel.PlatformDownloadRequest.Quantization(rawValue: parts[1])
    let versionRaw = parts[2]
    let version = CactusLanguageModel.PlatformDownloadRequest.Version(rawValue: versionRaw)
    let pro = parts.count > 3
      ? CactusLanguageModel.PlatformDownloadRequest.Pro(rawValue: parts[3])
      : nil
    return CactusLanguageModel.PlatformDownloadRequest(
      slug: slug,
      quantization: quantization,
      version: version,
      pro: pro
    )
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
  }
}
