#if !os(Android)
  import Cactus
  import CustomDump
  import Foundation
  import Testing

  @Suite
  struct `CactusModelDirectory tests` {
    @Test
    func `No Stored Models By Default`() {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      expectNoDifference(directory.storedModels(), [])
      expectNoDifference(directory.storedModelURL(for: CactusLanguageModel.testModelSlug), nil)
    }

    @Test
    func `Stores Model When Loading`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let url = try await directory.modelURL(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      expectNoDifference(directory.storedModelURL(for: CactusLanguageModel.testModelSlug), url)
      expectNoDifference(directory.storedModels().map(\.slug), [CactusLanguageModel.testModelSlug])
      expectNoDifference(directory.storedModels().map(\.url), [url])
    }

    @Test
    func `Removes Model From Storage`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      _ = try await directory.modelURL(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      try directory.removeModel(with: CactusLanguageModel.testModelSlug)

      expectNoDifference(directory.storedModels(), [])
      expectNoDifference(directory.storedModelURL(for: CactusLanguageModel.testModelSlug), nil)
    }

    @Test
    func `Shares Model Download Tasks`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let t1 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      let t2 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      expectNoDifference(t1 === t2, true)
    }

    @Test
    func `Creates Active Download Tasks`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      expectNoDifference(directory.activeDownloadTasks.isEmpty, true)

      let t1 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      let t2 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testVLMSlug,
        configuration: self.configuration
      )
      expectNoDifference(
        directory.activeDownloadTasks[CactusLanguageModel.testModelSlug] === t1,
        true
      )
      expectNoDifference(
        directory.activeDownloadTasks[CactusLanguageModel.testVLMSlug] === t2,
        true
      )
    }

    @Test
    func `Uses New Download Task After Completion`() async throws {
      let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())

      let t1 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      t1.resume()
      try await t1.waitForCompletion()

      let t2 = try directory.modelDownloadTask(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      expectNoDifference(t1 === t2, false)
    }

    @Test
    func `Returns Local URL When Loading Model For The Second Time`() async throws {
      final class CountingCreator: CactusModelsDirectory.DownloadTaskCreator, Sendable {
        let count = Lock(0)

        func downloadModelTask(
          slug: String,
          to destination: URL,
          configuration: URLSessionConfiguration
        ) -> CactusLanguageModel.DownloadTask {
          self.count.withLock { $0 += 1 }
          return CactusLanguageModel.downloadModelTask(
            slug: slug,
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

      let url = try await directory.modelURL(
        for: CactusLanguageModel.testModelSlug,
        configuration: self.configuration
      )
      let url2 = try await directory.modelURL(
        for: CactusLanguageModel.testModelSlug,
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
