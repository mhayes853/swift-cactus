#if !os(Android)
  import Cactus
  import CustomDump
  import Foundation
  import Testing

  #if canImport(Observation)
    import Observation
  #endif

  @Suite
  struct `CactusModelDirectory tests` {
    @Test
    func `No Stored Models By Default`() {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      expectNoDifference(directory.storedModels(), [])
      expectNoDifference(
        directory.storedModelURL(for: .lfm2_5_1_2bThinking()),
        nil
      )
    }

    @Test
    func `Stores Model When Loading`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let url = try await directory.modelURL(
        for: request,
        configuration: self.configuration
      )
      expectSameLocation(directory.storedModelURL(for: request), url)
      expectNoDifference(directory.storedModels().map(\.request), [request])
      expectSameLocation(directory.storedModels().map(\.url).first, url)
    }

    @Test
    func `Removes Model From Storage`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      _ = try await directory.modelURL(
        for: request,
        configuration: self.configuration
      )
      try directory.removeModel(with: request)

      expectNoDifference(directory.storedModels(), [])
      expectNoDifference(directory.storedModelURL(for: request), nil)
    }

    @Test
    func `Shares Model Download Tasks`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let t1 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      let t2 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      expectNoDifference(t1 === t2, true)
    }

    @Test
    func `Creates Active Download Tasks`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      expectNoDifference(directory.activeDownloadTasks.isEmpty, true)

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let t1 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      let vlmRequest = CactusLanguageModel.PlatformDownloadRequest.lfm2Vl_450m()
      let t2 = try directory.modelDownloadTask(
        for: vlmRequest,
        configuration: self.configuration
      )
      expectNoDifference(
        directory.activeDownloadTasks[request] === t1,
        true
      )
      expectNoDifference(
        directory.activeDownloadTasks[vlmRequest] === t2,
        true
      )
    }

    #if canImport(Observation)
      @Test
      @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
      func `Observes Newly Added Download Task`() async throws {
        let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

        let tasks = Lock(
          [[CactusLanguageModel.PlatformDownloadRequest: CactusLanguageModel.DownloadTask]]()
        )
        let token = observe {
          tasks.withLock { $0.append(directory.activeDownloadTasks) }
        }

        let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
        let t1 = try directory.modelDownloadTask(
          for: request,
          configuration: self.configuration
        )
        t1.resume()
        try await t1.waitForCompletion()

        try await Task.sleep(for: .seconds(0.1))

        tasks.withLock {
          expectNoDifference($0[0].isEmpty, true)
          expectNoDifference($0[1][request] === t1, true)
          expectNoDifference($0[2].isEmpty, true)
        }
        token.cancel()
      }
    #endif

    @Test
    func `Uses New Download Task After Completion`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let t1 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      t1.resume()
      try await t1.waitForCompletion()

      let t2 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      expectNoDifference(t1 === t2, false)
    }

    @Test
    func `Returns Local URL When Loading Model For The Second Time`() async throws {
      final class CountingCreator: CactusModelsDirectory.DownloadTaskCreator, Sendable {
        let count = Lock(0)

        func downloadModelTask(
          request: CactusLanguageModel.PlatformDownloadRequest,
          to destination: URL,
          configuration: URLSessionConfiguration
        ) -> CactusLanguageModel.DownloadTask {
          self.count.withLock { $0 += 1 }
          return CactusLanguageModel.downloadModelTask(
            request: request,
            to: destination,
            configuration: configuration
          )
        }
      }

      let creator = CountingCreator()
      let directory = CactusModelsDirectory(
        baseURL: temporaryModelDirectory(),
        downloadTaskCreator: creator
      )

      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let url = try await directory.modelURL(
        for: request,
        configuration: self.configuration
      )
      let url2 = try await directory.modelURL(
        for: request,
        configuration: self.configuration
      )
      expectNoDifference(url, url2)
      creator.count.withLock { expectNoDifference($0, 1) }
    }

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

    @Test
    func `Invokes Migration Delegate Before And After Migration`() throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let didCallWill = Lock(false)
      let didCallDid = Lock(false)
      let delegate = CallbackDelegate()
      delegate.onWillStartMigrationFromv1_5Tov1_7Structure = { directory in
        didCallWill.withLock { $0 = true }
      }
      delegate.onDidFinishMigrationFromv1_5Tov1_7Structure = { _, _ in
        didCallDid.withLock { $0 = true }
      }
      directory.delegate = delegate

      _ = try directory.migrateFromv1_5Tov1_7Structure()
      didCallWill.withLock { expectNoDifference($0, true) }
      didCallDid.withLock { expectNoDifference($0, true) }
    }

    @Test
    func `Invokes Deletion Delegate Before And After Removal`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      _ = try await directory.modelURL(for: request, configuration: self.configuration)

      let didCallWill = Lock(false)
      let didCallDid = Lock(false)
      let delegate = CallbackDelegate()
      delegate.onWillRemoveModel = { _, _ in
        didCallWill.withLock { $0 = true }
      }
      delegate.onDidRemoveModel = { _, _, result in
        didCallDid.withLock { $0 = true }
        expectNoDifference((try? result.get()) == nil, false)
      }
      directory.delegate = delegate

      try directory.removeModel(with: request)
      didCallWill.withLock { expectNoDifference($0, true) }
      didCallDid.withLock { expectNoDifference($0, true) }
    }

    @Test
    func `Invokes Migration Delegate When Download Is In Progress`() throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let didCallWill = Lock(false)
      let didCallDid = Lock(false)
      let delegate = CallbackDelegate()
      delegate.onWillStartMigrationFromv1_5Tov1_7Structure = { _ in
        didCallWill.withLock { $0 = true }
      }
      delegate.onDidFinishMigrationFromv1_5Tov1_7Structure = { _, _ in
        didCallDid.withLock { $0 = true }
      }
      directory.delegate = delegate

      _ = try directory.modelDownloadTask(for: request, configuration: self.configuration)
      _ = try directory.migrateFromv1_5Tov1_7Structure()
      didCallWill.withLock { expectNoDifference($0, true) }
      didCallDid.withLock { expectNoDifference($0, true) }
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

    private var configuration: URLSessionConfiguration {
      let configuration = URLSessionConfiguration.default
      configuration.protocolClasses = [TestURLProtocol.self]
      return configuration
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

  private final class TestURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
      true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      request
    }

    override func startLoading() {
      let data = try! Data(
        contentsOf: Bundle.module.url(forResource: "test", withExtension: "zip")!
      )
      client?
        .urlProtocol(
          self,
          didReceive: HTTPURLResponse(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["content-length": "\(data.count)"]
          )!,
          cacheStoragePolicy: .notAllowed
        )
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  private final class CallbackDelegate: CactusModelsDirectory.Delegate, @unchecked Sendable {
    var onWillStartMigrationFromv1_5Tov1_7Structure: (@Sendable (CactusModelsDirectory) -> Void)?
    var onDidFinishMigrationFromv1_5Tov1_7Structure:
      (
        @Sendable (
          CactusModelsDirectory,
          Result<CactusModelsDirectory.Migrationv1_5Tov1_7StructureResult, any Error>
        ) -> Void
      )?
    var onWillRemoveModel:
      (@Sendable (CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest) -> Void)?
    var onDidRemoveModel:
      (
        @Sendable (
          CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
          Result<Void, any Error>
        ) -> Void
      )?

    func modelsDirectoryWillStartMigrationFromv1_5Tov1_7Structure(
      _ directory: CactusModelsDirectory
    ) {
      self.onWillStartMigrationFromv1_5Tov1_7Structure?(directory)
    }

    func modelsDirectoryWillRemoveModel(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest
    ) {
      self.onWillRemoveModel?(directory, request)
    }

    func modelsDirectoryDidFinishMigrationFromv1_5Tov1_7Structure(
      _ directory: CactusModelsDirectory,
      result: Result<CactusModelsDirectory.Migrationv1_5Tov1_7StructureResult, any Error>
    ) {
      self.onDidFinishMigrationFromv1_5Tov1_7Structure?(directory, result)
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
