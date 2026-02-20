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
  /// This instance stores models inside
  /// ``CactusModelsDirectory/sharedDirectoryURL``/`cactus-models`.
  public static let shared = CactusModelsDirectory(
    baseURL: requireSharedDirectoryURL()
  )

  private struct State {
    var downloadTasks = [CactusLanguageModel.PlatformDownloadRequest: DownloadTaskEntry]()
    var downloadTaskCreator: any DownloadTaskCreator
    var delegate: (any Delegate)?
  }

  private struct DownloadTaskEntry {
    let task: CactusLanguageModel.DownloadTask
    let subscription: CactusSubscription
  }

  /// The base `URL` of this directory.
  public let baseURL: URL

  private let state: RecursiveLock<State>

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
    self.state = RecursiveLock(State(downloadTaskCreator: downloadTaskCreator))
  }
}

// MARK: - Delegate

extension CactusModelsDirectory {
  /// A delegate that observes events for ``CactusModelsDirectory``.
  ///
  /// Set ``CactusModelsDirectory/delegate`` to receive events from model directory operations.
  public protocol Delegate: Sendable {
    /// Called right before
    /// ``CactusModelsDirectory/migrateFromv1_5Tov1_7Structure()`` begins.
    ///
    /// - Parameter directory: The models directory performing the migration.
    func modelsDirectoryWillStartMigrationFromv1_5Tov1_7Structure(
      _ directory: CactusModelsDirectory
    )

    /// Called when
    /// ``CactusModelsDirectory/migrateFromv1_5Tov1_7Structure()`` finishes,
    /// either successfully or with an error.
    ///
    /// - Parameters:
    ///   - directory: The models directory that performed the migration.
    ///   - result: The migration result or the failure error.
    func modelsDirectoryDidFinishMigrationFromv1_5Tov1_7Structure(
      _ directory: CactusModelsDirectory,
      result: Result<Migrationv1_5Tov1_7StructureResult, any Error>
    )

    /// Called right before a model removal begins.
    ///
    /// - Parameters:
    ///   - directory: The models directory removing the model.
    ///   - request: The request identifying the model to remove.
    func modelsDirectoryWillRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest
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
      request: CactusLanguageModel.PlatformDownloadRequest,
      result: Result<Void, any Error>
    )
  }

  public var delegate: (any Delegate)? {
    get { self.state.withLock { $0.delegate } }
    set { self.state.withLock { $0.delegate = newValue } }
  }
}

extension CactusModelsDirectory.Delegate {
  public func modelsDirectoryWillStartMigrationFromv1_5Tov1_7Structure(
    _ directory: CactusModelsDirectory
  ) {}

  public func modelsDirectoryDidFinishMigrationFromv1_5Tov1_7Structure(
    _ directory: CactusModelsDirectory,
    result: Result<CactusModelsDirectory.Migrationv1_5Tov1_7StructureResult, any Error>
  ) {}

  public func modelsDirectoryWillRemoveModel(
    _ directory: CactusModelsDirectory,
    request: CactusLanguageModel.PlatformDownloadRequest
  ) {}

  public func modelsDirectoryDidRemoveModel(
    _ directory: CactusModelsDirectory,
    request: CactusLanguageModel.PlatformDownloadRequest,
    result: Result<Void, any Error>
  ) {}
}

// MARK: - Shared Directory

extension CactusModelsDirectory {
  #if canImport(Darwin)
    /// The shared base directory used by APIs such as ``CactusModelsDirectory/shared``.
    public static var sharedDirectoryURL: URL {
      get { _sharedDirectoryURL.withLock { $0 } }
      set { _sharedDirectoryURL.withLock { $0 = newValue } }
    }

    private static let _sharedDirectoryURL = Lock<URL>(
      URL._applicationSupportDirectory.appendingPathComponent("cactus-models", isDirectory: true)
    )
  #else
    /// The shared base directory used by APIs such as ``CactusModelsDirectory/shared``.
    ///
    /// This must be set by the application before accessing APIs that depend on a shared models
    /// directory.
    public static var sharedDirectoryURL: URL? {
      get { _sharedDirectoryURL.withLock { $0 } }
      set { _sharedDirectoryURL.withLock { $0 = newValue } }
    }

    private static let _sharedDirectoryURL = Lock<URL?>(nil)
  #endif
}

private func requireSharedDirectoryURL() -> URL {
  #if canImport(Darwin)
    return CactusModelsDirectory.sharedDirectoryURL
  #else
    if let sharedDirectoryURL = CactusModelsDirectory.sharedDirectoryURL {
      return sharedDirectoryURL
    }
    #if os(Android)
      fatalError(
        """
        Attempted to access the shared language models directory, but it has not been set.

        On Android, the shared models directory is tied to your application context. When your app
        launches, set `CactusModelsDirectory.sharedDirectoryURL` before using
        `CactusModelsDirectory.shared`.

            import Cactus
            import Android
            import AndroidNativeAppGlue

            @_silgen_name("android_main")
            public func android_main(_ app: UnsafeMutablePointer<android_app>) {
              CactusModelsDirectory.sharedDirectoryURL = URL(
                fileURLWithPath: app.pointee.activity.pointee.internalDataPath
              )
            }
        """
      )
    #elseif os(Linux)
      fatalError(
        """
        Attempted to access the shared language models directory, but it has not been set.

        On Linux, there is no default shared models directory. Set
        `CactusModelsDirectory.sharedDirectoryURL` during application startup before using
        `CactusModelsDirectory.shared`.

            import Cactus
            import Foundation

            CactusModelsDirectory.sharedDirectoryURL = URL(fileURLWithPath: "<models-directory>")
        """
      )
    #else
      fatalError(
        """
        Attempted to access the shared language models directory, but it has not been set.

        Set `CactusModelsDirectory.sharedDirectoryURL` before using `CactusModelsDirectory.shared`.
        """
      )
    #endif
  #endif
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
  @available(
    *,
    deprecated,
    message:
      "Use `modelURL(for:configuration:onDownloadProgress:)` with a `PlatformDownloadRequest` instead."
  )
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
  @available(
    *,
    deprecated,
    message: "Use `modelDownloadTask(for:configuration:)` with a `PlatformDownloadRequest` instead."
  )
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
      let destinationURL = self.destinationURL(for: request)
      try self.ensureParentDirectory(for: destinationURL)
      let task = try createTask(
        request,
        destinationURL,
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
  public var activeDownloadTasks:
    [CactusLanguageModel.PlatformDownloadRequest: CactusLanguageModel.DownloadTask]
  {
    self.observationRegistrar.access(self, keyPath: \.activeDownloadTasks)
    return self.state.withLock { state in state.downloadTasks.mapValues(\.task) }
  }

  /// All active ``CactusLanguageModel/DownloadTask`` instances currently managed by this
  /// directory, keyed by model slug.
  @available(
    *,
    deprecated,
    message: "Use `activeDownloadTasks` keyed by `PlatformDownloadRequest` instead."
  )
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
  @available(
    *,
    deprecated,
    message: "Use `storedModelURL(for:)` with a `PlatformDownloadRequest` instead."
  )
  public func storedModelURL(for slug: String) -> URL? {
    self.storedModelURL(for: CactusLanguageModel.PlatformDownloadRequest(slug: slug))
  }

  /// Returns the stored `URL` for the model with the specified request if one exists.
  ///
  /// - Parameter request: The platform download request for the model.
  public func storedModelURL(
    for request: CactusLanguageModel.PlatformDownloadRequest
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

      var models = [StoredModel]()
      for versionDirectory in versionDirectories {
        guard
          let isVersionDirectory = try? versionDirectory.resourceValues(forKeys: [.isDirectoryKey])
            .isDirectory,
          isVersionDirectory == true
        else {
          continue
        }
        let version = CactusLanguageModel.PlatformDownloadRequest.Version(
          rawValue: versionDirectory.lastPathComponent
        )
        guard
          let quantizationDirectories = try? FileManager.default.contentsOfDirectory(
            at: versionDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
          )
        else {
          continue
        }
        for quantizationDirectory in quantizationDirectories {
          guard
            let isQuantizationDirectory =
              try? quantizationDirectory.resourceValues(forKeys: [
                .isDirectoryKey
              ])
              .isDirectory,
            isQuantizationDirectory == true
          else {
            continue
          }
          let quantization = CactusLanguageModel.PlatformDownloadRequest.Quantization(
            rawValue: quantizationDirectory.lastPathComponent
          )
          guard
            let channelDirectories = try? FileManager.default.contentsOfDirectory(
              at: quantizationDirectory,
              includingPropertiesForKeys: [.isDirectoryKey],
              options: [.skipsHiddenFiles]
            )
          else {
            continue
          }
          for channelDirectory in channelDirectories {
            guard
              let isChannelDirectory =
                try? channelDirectory.resourceValues(forKeys: [.isDirectoryKey])
                .isDirectory,
              isChannelDirectory == true
            else {
              continue
            }
            let pro: CactusLanguageModel.PlatformDownloadRequest.Pro? =
              channelDirectory.lastPathComponent == Self.ordinaryDirectoryName
              ? nil
              : CactusLanguageModel.PlatformDownloadRequest.Pro(
                rawValue: channelDirectory.lastPathComponent
              )
            guard
              let modelDirectories = try? FileManager.default.contentsOfDirectory(
                at: channelDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
            else {
              continue
            }
            for modelDirectory in modelDirectories {
              guard
                let isModelDirectory =
                  try? modelDirectory.resourceValues(forKeys: [.isDirectoryKey])
                  .isDirectory,
                isModelDirectory == true
              else {
                continue
              }
              let request = CactusLanguageModel.PlatformDownloadRequest(
                slug: modelDirectory.lastPathComponent,
                quantization: quantization,
                version: version,
                pro: pro
              )
              models.append(StoredModel(request: request, url: modelDirectory))
            }
          }
        }
      }
      return models
    }
  }
}

// MARK: - Model Removing

extension CactusModelsDirectory {
  /// Removes the locally stored model with the specified `slug`.
  ///
  /// - Parameter slug: The model slug.
  @available(
    *,
    deprecated,
    message: "Use `removeModel(with:)` with a `PlatformDownloadRequest` instead."
  )
  public func removeModel(with slug: String) throws {
    try removeModel(with: CactusLanguageModel.PlatformDownloadRequest(slug: slug))
  }

  /// Removes the locally stored model with the specified request.
  ///
  /// - Parameter request: The platform download request for the model.
  public func removeModel(
    with request: CactusLanguageModel.PlatformDownloadRequest
  ) throws {
    let delegate = self.state.withLock { state in state.delegate }

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

// MARK: - Migrations

extension CactusModelsDirectory {
  /// The result produced by ``migrateFromv1_5Tov1_7Structure()``.
  ///
  /// Models from earlier versions than v1.7 are removed due to incompatibility with the engine.
  public struct Migrationv1_5Tov1_7StructureResult: Hashable, Sendable {
    /// Models that were moved from legacy directory names into the v1.7 directory structure.
    public let migrated: [StoredModel]

    /// Models that were removed because they target versions older than v1.7.
    public let removed: [StoredModel]

    /// Creates a migration result.
    ///
    /// - Parameters:
    ///   - migrated: Models that were migrated into the new structure.
    ///   - removed: Models that were removed during migration.
    public init(migrated: [StoredModel], removed: [StoredModel]) {
      self.migrated = migrated
      self.removed = removed
    }
  }

  /// Migrates legacy model directories from the v1.5 naming scheme to the v1.7 directory
  /// structure.
  ///
  /// Models from earlier versions than v1.7 are removed due to incompatibility with the engine.
  ///
  /// - Returns: A ``Migrationv1_5Tov1_7StructureResult`` describing migrated and removed models.
  @discardableResult
  public func migrateFromv1_5Tov1_7Structure() throws -> Migrationv1_5Tov1_7StructureResult {
    let delegate = self.state.withLock { state in state.delegate }

    delegate?.modelsDirectoryWillStartMigrationFromv1_5Tov1_7Structure(self)
    do {
      let result = try self.performMigrationFromv1_5Tov1_7Structure(delegate: delegate)
      delegate?
        .modelsDirectoryDidFinishMigrationFromv1_5Tov1_7Structure(
          self,
          result: Result<Migrationv1_5Tov1_7StructureResult, any Error>.success(result)
        )
      return result
    } catch {
      delegate?
        .modelsDirectoryDidFinishMigrationFromv1_5Tov1_7Structure(
          self,
          result: Result<Migrationv1_5Tov1_7StructureResult, any Error>.failure(error)
        )
      throw error
    }
  }

  private func performMigrationFromv1_5Tov1_7Structure(
    delegate: (any Delegate)?
  ) throws -> Migrationv1_5Tov1_7StructureResult {
    let legacyDirectories = self.legacyDirectoriesForMigration()
    guard !legacyDirectories.isEmpty else {
      return Migrationv1_5Tov1_7StructureResult(migrated: [], removed: [])
    }

    var migrated = [StoredModel]()
    var removed = [StoredModel]()

    for legacyDirectory in legacyDirectories {
      guard let request = self.requestForMigration(from: legacyDirectory) else {
        continue
      }

      let migrationResult = try self.migrateLegacyDirectory(
        legacyDirectory,
        request: request,
        delegate: delegate
      )
      switch migrationResult {
      case .migrated(let storedModel):
        migrated.append(storedModel)
      case .removed(let storedModel):
        removed.append(storedModel)
      }
    }

    return Migrationv1_5Tov1_7StructureResult(
      migrated: migrated.sorted { $0.url.path < $1.url.path },
      removed: removed.sorted { $0.url.path < $1.url.path }
    )
  }

  private enum MigrationActionResult {
    case migrated(StoredModel)
    case removed(StoredModel)
  }

  private func legacyDirectoriesForMigration() -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: self.baseURL,
      includingPropertiesForKeys: [.isDirectoryKey]
    )) ?? []
  }

  private func requestForMigration(
    from legacyDirectory: URL
  ) -> CactusLanguageModel.PlatformDownloadRequest? {
    guard
      let isDirectory = try? legacyDirectory.resourceValues(forKeys: [.isDirectoryKey])
        .isDirectory,
      isDirectory == true
    else {
      return nil
    }
    return self.request(fromLegacyDirectoryName: legacyDirectory.lastPathComponent)
  }

  private func migrateLegacyDirectory(
    _ legacyDirectory: URL,
    request: CactusLanguageModel.PlatformDownloadRequest,
    delegate: (any Delegate)?
  ) throws -> MigrationActionResult {
    let legacyStoredModel = StoredModel(request: request, url: legacyDirectory)

    if request.isOlderThanv1_7 {
      try self.removeLegacyModelDirectory(legacyDirectory, request: request, delegate: delegate)
      return .removed(legacyStoredModel)
    }

    let migratedModel = try self.moveLegacyModelDirectory(legacyDirectory, request: request)
    return .migrated(migratedModel)
  }

  private func removeLegacyModelDirectory(
    _ legacyDirectory: URL,
    request: CactusLanguageModel.PlatformDownloadRequest,
    delegate: (any Delegate)?
  ) throws {
    delegate?.modelsDirectoryWillRemoveModel(self, request: request)
    do {
      try FileManager.default.removeItem(at: legacyDirectory)
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

  private func moveLegacyModelDirectory(
    _ legacyDirectory: URL,
    request: CactusLanguageModel.PlatformDownloadRequest
  ) throws -> StoredModel {
    let destinationURL = self.migratedDestinationURL(for: request)
    try FileManager.default.createDirectory(
      at: destinationURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let destinationExists = FileManager.default.fileExists(atPath: destinationURL.path)
    if destinationExists {
      try FileManager.default.removeItem(at: legacyDirectory)
    } else {
      try FileManager.default.moveItem(at: legacyDirectory, to: destinationURL)
    }

    return StoredModel(request: request, url: destinationURL)
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModelsDirectory: _Observable {
}

// MARK: - Helpers

extension CactusModelsDirectory {
  static let ordinaryDirectoryName = "__ordinary__"

  private func migratedDestinationURL(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) -> URL {
    let proDirectoryName = request.pro?.rawValue ?? Self.ordinaryDirectoryName
    return self.baseURL
      .appendingPathComponent(request.version.rawValue, isDirectory: true)
      .appendingPathComponent(request.quantization.rawValue, isDirectory: true)
      .appendingPathComponent(proDirectoryName, isDirectory: true)
      .appendingPathComponent(request.slug, isDirectory: true)
  }

  private func request(
    fromLegacyDirectoryName name: String
  ) -> CactusLanguageModel.PlatformDownloadRequest? {
    let parts = name.components(separatedBy: "--")
    guard parts.count >= 3 else { return nil }
    let slug = parts[0]
    let quantization = CactusLanguageModel.PlatformDownloadRequest.Quantization(rawValue: parts[1])
    let version = CactusLanguageModel.PlatformDownloadRequest.Version(rawValue: parts[2])
    let pro =
      parts.count > 3
      ? CactusLanguageModel.PlatformDownloadRequest.Pro(rawValue: parts[3])
      : nil
    return CactusLanguageModel.PlatformDownloadRequest(
      slug: slug,
      quantization: quantization,
      version: version,
      pro: pro
    )
  }

  private func destinationURL(
    for request: CactusLanguageModel.PlatformDownloadRequest
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
}

extension CactusLanguageModel.PlatformDownloadRequest {
  fileprivate var isOlderThanv1_7: Bool {
    guard
      let numbers = self.versionNumbers(from: version.rawValue),
      let v1_7Numbers = self.versionNumbers(
        from: CactusLanguageModel.PlatformDownloadRequest.Version.v1_7.rawValue
      )
    else {
      return false
    }
    if numbers.0 != v1_7Numbers.0 {
      return numbers.0 < v1_7Numbers.0
    }
    return numbers.1 < v1_7Numbers.1
  }

  private func versionNumbers(from rawValue: String) -> (Int, Int)? {
    guard rawValue.first == "v" else { return nil }
    let components = rawValue.dropFirst().split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 2 else { return nil }
    guard let major = Int(components[0]), let minor = Int(components[1]) else { return nil }
    return (major, minor)
  }
}
