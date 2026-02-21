import class Foundation.FileManager
import struct Foundation.URL

// MARK: - v1.5 -> v1.7

extension CactusModelsDirectory {
  /// The result produced by ``migrateFromv1_5Tov1_7Structure()``.
  ///
  /// Models from earlier versions than v1.7 are removed due to incompatibility with the engine.
  public struct Migrationv1_5Tov1_7StructureResult: Hashable, Sendable {
    /// Models that were moved from legacy directory names into the v1.7 directory structure.
    public let migrated: [StoredModel]

    /// Models that were removed because they target versions older than v1.7.
    public let removed: [StoredModel]
  }

  /// Migrates legacy model directories from the v1.5 naming scheme to the v1.7 directory
  /// structure.
  ///
  /// Models from earlier versions than v1.7 are removed due to incompatibility with the engine.
  ///
  /// - Returns: A ``Migrationv1_5Tov1_7StructureResult`` describing migrated and removed models.
  @discardableResult
  public func migrateFromv1_5Tov1_7Structure() throws -> Migrationv1_5Tov1_7StructureResult {
    try self.withIsolatedAccess { directory in
      let delegate = directory.delegate
      let legacyDirectories = directory.legacyDirectoriesForMigration()
      guard !legacyDirectories.isEmpty else {
        return Migrationv1_5Tov1_7StructureResult(migrated: [], removed: [])
      }

      var migrated = [StoredModel]()
      var removed = [StoredModel]()

      for legacyDirectory in legacyDirectories {
        guard let request = directory.requestForMigration(from: legacyDirectory) else {
          continue
        }

        let migrationResult = try directory.migrateLegacyDirectory(
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

// MARK: - Helpers

extension CactusModelsDirectory {
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
