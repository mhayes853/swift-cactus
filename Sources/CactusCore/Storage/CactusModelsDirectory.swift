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
/// let request = CactusModel.PlatformDownloadRequest.qwen3_0_6b()
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(for: request)
/// let model = try CactusModel(from: modelURL)
///
/// // ...
/// ```
public final class CactusModelsDirectory: Sendable {
  #if canImport(Darwin)
    /// A shared models directory instance.
    public static let shared = CactusModelsDirectory(
      baseURL: URL._applicationSupportDirectory.appendingPathComponent(
        "cactus-models",
        isDirectory: true
      )
    )
  #endif

  private struct State {
    var downloadTasks = [CactusModel.PlatformDownloadRequest: DownloadTaskEntry]()
    var delegate: (any Delegate)?
  }

  private struct DownloadTaskEntry {
    let task: CactusModel.DownloadTask
    let subscription: CactusSubscription
  }

  /// The base `URL` of this directory.
  public let baseURL: URL

  private let state: RecursiveLock<State>

  private let observationRegistrar = _ObservationRegistrar()

  /// Creates a model directory.
  /// Creates a model directory.
  ///
  /// - Parameter baseURL: The `URL` of the directory.
  public init(baseURL: URL) {
    self.baseURL = baseURL
    self.state = RecursiveLock(State())
  }
}

// MARK: - Delegate

extension CactusModelsDirectory {
  /// A delegate that observes events for ``CactusModelsDirectory``.
  ///
  /// Set ``CactusModelsDirectory/delegate`` to receive events from model directory operations.
  public protocol Delegate: Sendable {
    /// Called right before a model removal begins.
    ///
    /// - Parameters:
    ///   - directory: The models directory removing the model.
    ///   - request: The request identifying the model to remove.
    func modelsDirectoryWillRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusModel.PlatformDownloadRequest
    )

    /// Called when a model removal finishes, either successfully or with an
    /// error.
    ///
    /// - Parameters:
    ///   - directory: The models directory that attempted the removal.
    ///   - request: The request identifying the model that was removed.
    ///   - result: `success(())` on success, or the failure error.
    func modelsDirectoryDidRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusModel.PlatformDownloadRequest,
      result: Result<Void, any Error>
    )

    /// Called right before a new download task is created.
    ///
    /// - Parameters:
    ///   - directory: The models directory creating the download task.
    ///   - request: The request identifying the model to download.
    ///   - task: The download task that was created.
    func modelsDirectoryDidCreateDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusModel.PlatformDownloadRequest,
      task: CactusModel.DownloadTask
    )

    /// Called when a download task finishes, either successfully or with an
    /// error.
    ///
    /// - Parameters:
    ///   - directory: The models directory that managed the download task.
    ///   - request: The request identifying the model download.
    ///   - task: The completed download task.
    ///   - result: `success(URL)` on success, or the failure error.
    func modelsDirectoryDidCompleteDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusModel.PlatformDownloadRequest,
      task: CactusModel.DownloadTask,
      result: Result<URL, any Error>
    )

    /// Called when a download task needs to be created.
    ///
    /// - Parameters:
    ///   - directory: The models directory creating the download task.
    ///   - request: The request identifying the model to download.
    ///   - destination: The destination URL for the downloaded model.
    ///   - configuration: The URL session configuration to use.
    /// - Returns: The download task to use for downloading the model.
    func modelsDirectoryWillCreateDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusModel.PlatformDownloadRequest,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) -> CactusModel.DownloadTask
  }

  public var delegate: (any Delegate)? {
    get { self.state.withLock { $0.delegate } }
    set { self.state.withLock { $0.delegate = newValue } }
  }
}

extension CactusModelsDirectory.Delegate {
  public func modelsDirectoryWillRemoveModel(
    _ directory: CactusModelsDirectory,
    request: CactusModel.PlatformDownloadRequest
  ) {}

  public func modelsDirectoryDidRemoveModel(
    _ directory: CactusModelsDirectory,
    request: CactusModel.PlatformDownloadRequest,
    result: Result<Void, any Error>
  ) {}

  public func modelsDirectoryDidCreateDownloadTask(
    _ directory: CactusModelsDirectory,
    request: CactusModel.PlatformDownloadRequest,
    task: CactusModel.DownloadTask
  ) {}

  public func modelsDirectoryDidCompleteDownloadTask(
    _ directory: CactusModelsDirectory,
    request: CactusModel.PlatformDownloadRequest,
    task: CactusModel.DownloadTask,
    result: Result<URL, any Error>
  ) {}

  public func modelsDirectoryWillCreateDownloadTask(
    _ directory: CactusModelsDirectory,
    request: CactusModel.PlatformDownloadRequest,
    to destination: URL,
    configuration: URLSessionConfiguration
  ) -> CactusModel.DownloadTask {
    CactusModel.downloadModelTask(
      request: request,
      to: destination,
      configuration: configuration
    )
  }
}

// MARK: - Model Loading

extension CactusModelsDirectory {
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
    for request: CactusModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusModel.DownloadProgress, any Error>) -> Void = { _ in
      }
  ) async throws -> URL {
    try await self.modelURL(
      for: request,
      configuration: configuration,
      createTask: self.modelDownloadTask(for:configuration:),
      onDownloadProgress: onDownloadProgress
    )
  }

  private func modelURL(
    for request: CactusModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default,
    createTask: (
      CactusModel.PlatformDownloadRequest,
      URLSessionConfiguration
    ) throws -> CactusModel.DownloadTask,
    onDownloadProgress:
      @escaping @Sendable (Result<CactusModel.DownloadProgress, any Error>) -> Void = { _ in
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

  /// Returns a ``CactusModel/DownloadTask`` for the model with the specified request.
  ///
  /// If another download task is in progress, then this method will return the in-progress download task.
  ///
  /// - Parameters:
  ///   - request: The platform download request for the model.
  ///   - configuration: A `URLSessionConfiguration` to use for downloading.
  public func modelDownloadTask(
    for request: CactusModel.PlatformDownloadRequest,
    configuration: URLSessionConfiguration = .default
  ) throws -> CactusModel.DownloadTask {
    try self.state.withLock { state in
      if let entry = state.downloadTasks[request] {
        return entry.task
      }
      try self.ensureDirectory()
      let destinationURL = self.destinationURL(for: request)
      try self.ensureParentDirectory(for: destinationURL)
      let task: CactusModel.DownloadTask
      if let delegate = state.delegate {
        task = delegate.modelsDirectoryWillCreateDownloadTask(
          self,
          request: request,
          to: destinationURL,
          configuration: configuration
        )
      } else {
        task = CactusModel.downloadModelTask(
          request: request,
          to: destinationURL,
          configuration: configuration
        )
      }
      let subscription = task.onProgress { [weak self] progress in
        guard let self else { return }
        switch progress {
        case .failure(let error):
          self.handleDownloadTaskCompletion(for: request, task: task, result: .failure(error))
        case .success(.finished(let url)):
          self.handleDownloadTaskCompletion(for: request, task: task, result: .success(url))
        default:
          break
        }
      }
      self.observationRegistrar.withMutation(of: self, keyPath: \.activeDownloadTasks) {
        state.downloadTasks[request] = DownloadTaskEntry(task: task, subscription: subscription)
      }
      state.delegate?.modelsDirectoryDidCreateDownloadTask(self, request: request, task: task)
      return task
    }
  }

  private func handleDownloadTaskCompletion(
    for request: CactusModel.PlatformDownloadRequest,
    task: CactusModel.DownloadTask,
    result: Result<URL, any Error>
  ) {
    let completion = self.completeDownloadTaskEntry(for: request)
    guard completion.didRemoveTask else { return }
    completion.delegate?
      .modelsDirectoryDidCompleteDownloadTask(
        self,
        request: request,
        task: task,
        result: result
      )
  }

  /// All active ``CactusModel/DownloadTask`` instances currently managed by this
  /// directory.
  public var activeDownloadTasks:
    [CactusModel.PlatformDownloadRequest: CactusModel.DownloadTask]
  {
    self.observationRegistrar.access(self, keyPath: \.activeDownloadTasks)
    return self.state.withLock { state in state.downloadTasks.mapValues(\.task) }
  }

}

// MARK: - Stored Models

extension CactusModelsDirectory {
  /// A model stored inside a ``CactusModelsDirectory``.
  public struct StoredModel: Hashable, Sendable {
    /// The platform download request used for this model.
    public let request: CactusModel.PlatformDownloadRequest

    /// The `URL` of the model inside the directory.
    public let url: URL
  }

  /// Returns the stored `URL` for the model with the specified request if one exists.
  ///
  /// - Parameter request: The platform download request for the model.
  public func storedModelURL(
    for request: CactusModel.PlatformDownloadRequest
  ) -> URL? {
    self.state.withLock { _ in
      let destinationURL = self.destinationURL(for: request)
      var isDirectory = ObjCBool(false)
      let doesExist = FileManager.default.fileExists(
        atPath: destinationURL.relativePath,
        isDirectory: &isDirectory
      )
      return doesExist && isDirectory.boolValue ? destinationURL : nil
    }
  }

  /// Returns an array of all ``StoredModel`` instances in this directory.
  public func storedModels() -> [StoredModel] {
    self.state.withLock { _ in
      guard
        let versionDirectories = try? FileManager.default.contentsOfDirectory(
          at: self.baseURL,
          includingPropertiesForKeys: [.isDirectoryKey],
          options: [.skipsHiddenFiles]
        )
      else {
        return []
      }

      return versionDirectories.flatMap { versionDirectory in
        self.storedModels(inVersionDirectory: versionDirectory)
      }
    }
  }

  private func storedModels(inVersionDirectory versionDirectory: URL) -> [StoredModel] {
    guard
      let isVersionDirectory = try? versionDirectory.resourceValues(forKeys: [.isDirectoryKey])
        .isDirectory,
      isVersionDirectory == true
    else {
      return []
    }
    let version = CactusModel.PlatformDownloadRequest.Version(
      rawValue: versionDirectory.lastPathComponent
    )
    guard
      let quantizationDirectories = try? FileManager.default.contentsOfDirectory(
        at: versionDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    return quantizationDirectories.flatMap { quantizationDirectory in
      self.storedModels(inQuantizationDirectory: quantizationDirectory, version: version)
    }
  }

  private func storedModels(
    inQuantizationDirectory quantizationDirectory: URL,
    version: CactusModel.PlatformDownloadRequest.Version
  ) -> [StoredModel] {
    guard
      let isQuantizationDirectory =
        try? quantizationDirectory.resourceValues(forKeys: [.isDirectoryKey])
        .isDirectory,
      isQuantizationDirectory == true
    else {
      return []
    }
    let quantization = CactusModel.PlatformDownloadRequest.Quantization(
      rawValue: quantizationDirectory.lastPathComponent
    )
    guard
      let channelDirectories = try? FileManager.default.contentsOfDirectory(
        at: quantizationDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    return channelDirectories.flatMap { channelDirectory in
      self.storedModels(
        inChannelDirectory: channelDirectory,
        version: version,
        quantization: quantization
      )
    }
  }

  private func storedModels(
    inChannelDirectory channelDirectory: URL,
    version: CactusModel.PlatformDownloadRequest.Version,
    quantization: CactusModel.PlatformDownloadRequest.Quantization
  ) -> [StoredModel] {
    guard
      let isChannelDirectory =
        try? channelDirectory.resourceValues(forKeys: [.isDirectoryKey])
        .isDirectory,
      isChannelDirectory == true
    else {
      return []
    }
    let pro: CactusModel.PlatformDownloadRequest.Pro? =
      channelDirectory.lastPathComponent == Self.ordinaryDirectoryName
      ? nil
      : CactusModel.PlatformDownloadRequest.Pro(
        rawValue: channelDirectory.lastPathComponent
      )
    guard
      let modelDirectories = try? FileManager.default.contentsOfDirectory(
        at: channelDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    return modelDirectories.compactMap { modelDirectory in
      self.storedModel(
        inModelDirectory: modelDirectory,
        version: version,
        quantization: quantization,
        pro: pro
      )
    }
  }

  private func storedModel(
    inModelDirectory modelDirectory: URL,
    version: CactusModel.PlatformDownloadRequest.Version,
    quantization: CactusModel.PlatformDownloadRequest.Quantization,
    pro: CactusModel.PlatformDownloadRequest.Pro?
  ) -> StoredModel? {
    guard
      let isModelDirectory =
        try? modelDirectory.resourceValues(forKeys: [.isDirectoryKey])
        .isDirectory,
      isModelDirectory == true
    else {
      return nil
    }
    let request = CactusModel.PlatformDownloadRequest(
      slug: modelDirectory.lastPathComponent,
      quantization: quantization,
      version: version,
      pro: pro
    )
    return StoredModel(request: request, url: modelDirectory)
  }
}

// MARK: - Model Removing

extension CactusModelsDirectory {
  /// Removes the locally stored model with the specified request.
  ///
  /// - Parameter request: The platform download request for the model.
  public func removeModel(
    with request: CactusModel.PlatformDownloadRequest
  ) throws {
    try self.state.withLock { state in
      try self._removeModel(request: request, state: state)
    }
  }

  /// Removes all stored models that match the given predicate.
  ///
  /// - Parameter predicate: A closure that takes a ``StoredModel`` and returns a `Bool`
  ///   indicating whether the model should be removed.
  public func removeModels(where predicate: (StoredModel) -> Bool) throws {
    try self.state.withLock { state in
      let modelsToRemove = self.storedModels().filter(predicate)

      var errors: [any Error] = []
      for model in modelsToRemove {
        do {
          try self._removeModel(request: model.request, state: state)
        } catch {
          errors.append(error)
        }
      }

      if !errors.isEmpty {
        throw RemoveModelsError(errors: errors)
      }
    }
  }

  private func _removeModel(
    request: CactusModel.PlatformDownloadRequest,
    state: sending State
  ) throws {
    let delegate = state.delegate

    delegate?.modelsDirectoryWillRemoveModel(self, request: request)
    do {
      try FileManager.default.removeItem(at: self.destinationURL(for: request))
      delegate?
        .modelsDirectoryDidRemoveModel(
          self,
          request: request,
          result: Result<Void, any Error>.success(())
        )
    } catch {
      delegate?
        .modelsDirectoryDidRemoveModel(
          self,
          request: request,
          result: Result<Void, any Error>.failure(error)
        )
      throw error
    }
  }
}

extension CactusModelsDirectory {
  /// Provides isolated access to the models directory for the duration of the specified closure.
  //
  /// - Parameter body: A closure to perform isolated work.
  /// - Returns: Whatever `body` returns.
  public func withIsolatedAccess<T>(
    _ body: @Sendable (CactusModelsDirectory) throws -> sending T
  ) rethrows -> sending T {
    try self.state.withLock { _ in try body(self) }
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModelsDirectory: _Observable {
}

// MARK: - Helpers

extension CactusModelsDirectory {
  /// An error that aggregates multiple removal failures.
  public struct RemoveModelsError: Error, Sendable {
    /// The errors that occurred during model removal.
    public let errors: [any Error]
  }

  static let ordinaryDirectoryName = "__ordinary__"

  private func destinationURL(
    for request: CactusModel.PlatformDownloadRequest
  ) -> URL {
    let proDirectoryName = request.pro?.rawValue ?? Self.ordinaryDirectoryName
    return self.baseURL
      .appendingPathComponent(request.version.rawValue, isDirectory: true)
      .appendingPathComponent(request.quantization.rawValue, isDirectory: true)
      .appendingPathComponent(proDirectoryName, isDirectory: true)
      .appendingPathComponent(request.slug, isDirectory: true)
  }

  private func ensureParentDirectory(for url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
  }

  private func completeDownloadTaskEntry(
    for request: CactusModel.PlatformDownloadRequest
  ) -> (delegate: (any Delegate)?, didRemoveTask: Bool) {
    self.state.withLock { state in
      var didRemoveTask = false
      self.observationRegistrar.withMutation(of: self, keyPath: \.activeDownloadTasks) {
        didRemoveTask = state.downloadTasks.removeValue(forKey: request) != nil
      }
      return (state.delegate, didRemoveTask)
    }
  }
}
