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
      directory.delegate = CallbackDelegate()

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
      directory.delegate = CallbackDelegate()

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
    func `Removes Models Matching Predicate`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      directory.delegate = CallbackDelegate()

      let request1 = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()
      let request2 = CactusLanguageModel.PlatformDownloadRequest.lfm2Vl_450m()
      _ = try await directory.modelURL(for: request1, configuration: self.configuration)
      _ = try await directory.modelURL(for: request2, configuration: self.configuration)

      try directory.removeModels { $0.request == request1 }

      expectNoDifference(directory.storedModels().map(\.request), [request2])
    }

    @Test
    func `Shares Model Download Tasks`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      directory.delegate = CallbackDelegate()

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
      directory.delegate = CallbackDelegate()

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
        directory.delegate = CallbackDelegate()

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
      directory.delegate = CallbackDelegate()

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
    func `Invokes Download Delegate Before Creation And After Completion`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let request = CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking()

      let didCallDid = Lock(false)
      let didRequest = Lock<CactusLanguageModel.PlatformDownloadRequest?>(nil)
      let didSucceed = Lock(false)
      let didFinishURL = Lock<URL?>(nil)
      let didTask = Lock<CactusLanguageModel.DownloadTask?>(nil)

      final class TestDelegate: CactusModelsDirectory.Delegate, @unchecked Sendable {
        var onDidCompleteDownloadTask:
          (
            @Sendable (
              CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
              CactusLanguageModel.DownloadTask,
              Result<URL, any Error>
            ) -> Void
          )?

        func modelsDirectoryWillCreateDownloadTask(
          _ directory: CactusModelsDirectory,
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

        func modelsDirectoryDidCompleteDownloadTask(
          _ directory: CactusModelsDirectory,
          request: CactusLanguageModel.PlatformDownloadRequest,
          task: CactusLanguageModel.DownloadTask,
          result: Result<URL, any Error>
        ) {
          onDidCompleteDownloadTask?(directory, request, task, result)
        }
      }

      let delegate = TestDelegate()
      delegate.onDidCompleteDownloadTask = { _, request, task, result in
        didCallDid.withLock { $0 = true }
        didRequest.withLock { $0 = request }
        didSucceed.withLock { $0 = (try? result.get()) != nil }
        didFinishURL.withLock { $0 = try? result.get() }
        didTask.withLock { $0 = task }
      }
      directory.delegate = delegate

      let task = try directory.modelDownloadTask(for: request, configuration: self.configuration)
      task.resume()
      let completedURL = try await task.waitForCompletion()

      didCallDid.withLock { expectNoDifference($0, true) }
      didRequest.withLock { expectNoDifference($0, request) }
      didSucceed.withLock { expectNoDifference($0, true) }
      didFinishURL.withLock { expectSameLocation($0, completedURL) }
      didTask.withLock { expectNoDifference($0 === task, true) }
    }

    @Test
    func `Returns Local URL When Loading Model For The Second Time`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      let delegate = CallbackDelegate()
      directory.delegate = delegate

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
      delegate.downloadTaskCount.withLock { expectNoDifference($0, 1) }
    }

    @Test
    func `Invokes Deletion Delegate Before And After Removal`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
      directory.delegate = CallbackDelegate()

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
    var onWillRemoveModel:
      (@Sendable (CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest) -> Void)?
    var onDidRemoveModel:
      (
        @Sendable (
          CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
          Result<Void, any Error>
        ) -> Void
      )?
    var onWillCreateDownloadTask:
      (
        @Sendable (
          CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
          CactusLanguageModel.DownloadTask
        ) -> Void
      )?
    var onDidCompleteDownloadTask:
      (
        @Sendable (
          CactusModelsDirectory, CactusLanguageModel.PlatformDownloadRequest,
          CactusLanguageModel.DownloadTask,
          Result<URL, any Error>
        ) -> Void
      )?
    var downloadTaskCount = Lock(0)

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

    func modelsDirectoryDidCreateDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest,
      task: CactusLanguageModel.DownloadTask
    ) {
      self.onWillCreateDownloadTask?(directory, request, task)
    }

    func modelsDirectoryDidCompleteDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest,
      task: CactusLanguageModel.DownloadTask,
      result: Result<URL, any Error>
    ) {
      self.onDidCompleteDownloadTask?(directory, request, task, result)
    }

    func modelsDirectoryWillCreateDownloadTask(
      _ directory: CactusModelsDirectory,
      request: CactusLanguageModel.PlatformDownloadRequest,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) -> CactusLanguageModel.DownloadTask {
      self.downloadTaskCount.withLock { $0 += 1 }
      return CactusLanguageModel.downloadModelTask(
        request: request,
        to: destination,
        configuration: configuration
      )
    }
  }
#endif
