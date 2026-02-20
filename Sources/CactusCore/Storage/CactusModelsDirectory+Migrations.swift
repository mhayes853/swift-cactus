import class Foundation.FileManager
import struct Foundation.URL

extension CactusModelsDirectory {
  public struct Migrationv1_5Tov1_7StructureResult: Hashable, Sendable {
    public let migrated: [StoredModel]
    public let removed: [StoredModel]

    public init(migrated: [StoredModel], removed: [StoredModel]) {
      self.migrated = migrated
      self.removed = removed
    }
  }

  @discardableResult
  public func migrateFromv1_5Tov1_7Structure() throws -> Migrationv1_5Tov1_7StructureResult {
    guard
      let legacyDirectories = try? FileManager.default.contentsOfDirectory(
        at: self.baseURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return Migrationv1_5Tov1_7StructureResult(migrated: [], removed: [])
    }

    var migrated = [StoredModel]()
    var removed = [StoredModel]()

    for legacyDirectory in legacyDirectories {
      guard
        let isDirectory = try? legacyDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
        isDirectory == true,
        let request = self.request(fromLegacyDirectoryName: legacyDirectory.lastPathComponent)
      else {
        continue
      }

      let legacyStoredModel = StoredModel(request: request, url: legacyDirectory)
      if self.isVersionOlderThanv1_7(request.version) {
        try FileManager.default.removeItem(at: legacyDirectory)
        removed.append(legacyStoredModel)
        continue
      }

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

      migrated.append(StoredModel(request: request, url: destinationURL))
    }

    return Migrationv1_5Tov1_7StructureResult(
      migrated: migrated.sorted { $0.url.path < $1.url.path },
      removed: removed.sorted { $0.url.path < $1.url.path }
    )
  }

  private func migratedDestinationURL(for request: CactusLanguageModel.PlatformDownloadRequest) -> URL {
    let proDirectoryName = request.pro?.rawValue ?? Self.ordinaryDirectoryName
    return self.baseURL
      .appendingPathComponent(request.version.rawValue, isDirectory: true)
      .appendingPathComponent(request.quantization.rawValue, isDirectory: true)
      .appendingPathComponent(proDirectoryName, isDirectory: true)
      .appendingPathComponent(request.slug, isDirectory: true)
  }

  private func request(fromLegacyDirectoryName name: String) -> CactusLanguageModel.PlatformDownloadRequest?
  {
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

  private func isVersionOlderThanv1_7(_ version: CactusLanguageModel.PlatformDownloadRequest.Version)
    -> Bool
  {
    guard
      let numbers = Self.versionNumbers(from: version.rawValue),
      let v1_7Numbers = Self.versionNumbers(
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

  private static func versionNumbers(from rawValue: String) -> (Int, Int)? {
    guard rawValue.first == "v" else { return nil }
    let components = rawValue.dropFirst().split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 2 else { return nil }
    guard let major = Int(components[0]), let minor = Int(components[1]) else { return nil }
    return (major, minor)
  }
}
