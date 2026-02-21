#if !os(Android)
  import Cactus
  import CustomDump
  import Foundation
  import Testing

  @Suite
  struct `CactusModelDirectoryMigrations tests` {
    @Test
    func `Successful Migration Migrates Compatible Models To The New Format`() throws {
      let baseURL = temporaryModelDirectory()
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let directory = CactusModelsDirectory(baseURL: baseURL)

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let proRequest = CactusLanguageModel.PlatformDownloadRequest.whisperSmall(pro: .apple)
      let legacyURL = try self.createLegacyStoredModel(request: request, in: baseURL)
      let legacyProURL = try self.createLegacyStoredModel(request: proRequest, in: baseURL)

      let result = try directory.migrateFromv1_5Tov1_7Structure()

      let migratedRequests = result.migrated.map(\.request)
      expectNoDifference(Set(migratedRequests), Set([request, proRequest]))
      expectNoDifference(result.removed, [])

      expectNoDifference(FileManager.default.fileExists(atPath: legacyURL.path), false)
      expectNoDifference(FileManager.default.fileExists(atPath: legacyProURL.path), false)

      let expectedURL =
        baseURL
        .appendingPathComponent("v1.7", isDirectory: true)
        .appendingPathComponent("int4", isDirectory: true)
        .appendingPathComponent("__ordinary__", isDirectory: true)
        .appendingPathComponent(request.slug, isDirectory: true)
      let expectedProURL =
        baseURL
        .appendingPathComponent("v1.7", isDirectory: true)
        .appendingPathComponent("int4", isDirectory: true)
        .appendingPathComponent("apple", isDirectory: true)
        .appendingPathComponent(proRequest.slug, isDirectory: true)

      expectSameLocation(directory.storedModelURL(for: request), expectedURL)
      expectSameLocation(directory.storedModelURL(for: proRequest), expectedProURL)
    }

    @Test
    func `Successful Migration Removes Outdated Models`() throws {
      let baseURL = temporaryModelDirectory()
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let directory = CactusModelsDirectory(baseURL: baseURL)

      let outdatedRequest = CactusLanguageModel.PlatformDownloadRequest(
        slug: "whisper-small",
        quantization: .int4,
        version: .v1_5
      )
      let supportedRequest = CactusLanguageModel.PlatformDownloadRequest.whisperSmall()
      let outdatedLegacyURL = try self.createLegacyStoredModel(
        request: outdatedRequest,
        in: baseURL
      )
      _ = try self.createLegacyStoredModel(request: supportedRequest, in: baseURL)

      let result = try directory.migrateFromv1_5Tov1_7Structure()

      expectNoDifference(
        Set(result.removed.map(\.request)),
        Set([outdatedRequest])
      )
      expectNoDifference(
        Set(result.migrated.map(\.request)),
        Set([supportedRequest])
      )

      expectNoDifference(FileManager.default.fileExists(atPath: outdatedLegacyURL.path), false)
      expectNoDifference(directory.storedModelURL(for: outdatedRequest), nil)
      expectNoDifference(directory.storedModelURL(for: supportedRequest) == nil, false)
    }

    @Test
    func `Invokes Deletion Delegate Methods During Migration Removals`() throws {
      let baseURL = temporaryModelDirectory()
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let directory = CactusModelsDirectory(baseURL: baseURL)

      let outdatedRequest = CactusLanguageModel.PlatformDownloadRequest(
        slug: "whisper-small",
        quantization: .int4,
        version: .v1_5
      )
      _ = try self.createLegacyStoredModel(request: outdatedRequest, in: baseURL)

      let didCallWill = Lock(false)
      let didCallDid = Lock(false)
      let willRequest = Lock<CactusLanguageModel.PlatformDownloadRequest?>(nil)
      let didRequest = Lock<CactusLanguageModel.PlatformDownloadRequest?>(nil)
      let didSucceed = Lock(false)

      let delegate = CallbackDelegate()
      delegate.onWillRemoveModel = { _, request in
        didCallWill.withLock { $0 = true }
        willRequest.withLock { $0 = request }
      }
      delegate.onDidRemoveModel = { _, request, result in
        didCallDid.withLock { $0 = true }
        didRequest.withLock { $0 = request }
        didSucceed.withLock { $0 = (try? result.get()) != nil }
      }
      directory.delegate = delegate

      _ = try directory.migrateFromv1_5Tov1_7Structure()

      didCallWill.withLock { expectNoDifference($0, true) }
      didCallDid.withLock { expectNoDifference($0, true) }
      willRequest.withLock { expectNoDifference($0, outdatedRequest) }
      didRequest.withLock { expectNoDifference($0, outdatedRequest) }
      didSucceed.withLock { expectNoDifference($0, true) }
    }

    private func createLegacyStoredModel(
      request: CactusLanguageModel.PlatformDownloadRequest,
      in baseURL: URL
    ) throws -> URL {
      let legacyDirectoryName = [
        request.slug,
        request.quantization.rawValue,
        request.version.rawValue,
        request.pro?.rawValue
      ]
      .compactMap { $0 }
      .joined(separator: "--")
      let legacyURL = baseURL.appendingPathComponent(legacyDirectoryName, isDirectory: true)
      try FileManager.default.createDirectory(at: legacyURL, withIntermediateDirectories: true)
      let markerURL = legacyURL.appendingPathComponent("weights.bin")
      FileManager.default.createFile(atPath: markerURL.path, contents: Data([0x01]))
      return legacyURL
    }
  }

  private func expectSameLocation(_ lhs: URL?, _ rhs: URL?) {
    guard let lhs, let rhs else {
      expectNoDifference(lhs, rhs)
      return
    }
    let lhsPath = lhs.resolvingSymlinksInPath().standardizedFileURL.path
    let rhsPath = rhs.resolvingSymlinksInPath().standardizedFileURL.path
    expectNoDifference(lhsPath, rhsPath)
  }

  private final class CallbackDelegate: CactusModelsDirectory.Delegate, @unchecked Sendable {
    var onWillRemoveModel:
      (@Sendable (CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest) -> Void)?
    var onDidRemoveModel:
      (
        @Sendable (
          CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
          Result<Void, any Error>
        ) -> Void
      )?

    func modelsDirectoryWillRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest
    ) {
      self.onWillRemoveModel?(directory, request)
    }

    func modelsDirectoryDidRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest,
      result: Result<Void, any Error>
    ) {
      self.onDidRemoveModel?(directory, request, result)
    }
  }
#endif
