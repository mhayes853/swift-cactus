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
        directory.storedModelURL(for: CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)),
        nil
      )
    }

    @Test
    func `Stores Model When Loading`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
      let t1 = try directory.modelDownloadTask(
        for: request,
        configuration: self.configuration
      )
      let vlmRequest = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testVLMSlug)
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

        let tasks = Lock([[CactusLanguageModel.PlatformDownloadRequest: CactusLanguageModel.DownloadTask]]())
        let token = observe {
          tasks.withLock { $0.append(directory.activeDownloadTasks) }
        }

        let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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

      let request = CactusLanguageModel.PlatformDownloadRequest(slug: CactusLanguageModel.testModelSlug)
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
#endif
