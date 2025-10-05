import CactusEngine
import CustomDump
import Foundation
import Testing

@Suite("CactusLanguageModel+Downloading tests")
struct CactusLanguageModelDownloadingTests {
  @Test("Task Not Finished By Default")
  func testNotFinishedByDefault() async throws {
    let metadata = try await self.modelMetadata()
    let task = CactusLanguageModel.downloadModelTask(with: metadata, to: self.temporaryURL())
    expectNoDifference(task.isFinished, false)
  }

  @Test("Download Model With Task")
  func downloadModelWithTask() async throws {
    let metadata = try await self.modelMetadata()
    let task = CactusLanguageModel.downloadModelTask(with: metadata, to: self.temporaryURL())

    let progress = Lock([CactusLanguageModel.DownloadProgress?]())
    let subscription = task.onProgress { result in
      progress.withLock { $0.append(try? result.get()) }
    }
    task.start()
    let url = try await task.finishedDestinationURL()
    defer { try? FileManager.default.removeItem(at: url) }
    subscription.cancel()

    expectNoDifference(task.isFinished, true)
    progress.withLock {
      let containsDownloading = $0.contains {
        switch $0 {
        case .downloading: true
        default: false
        }
      }
      let containsUnzipping = $0.contains {
        switch $0 {
        case .unzipping: true
        default: false
        }
      }
      expectNoDifference(containsDownloading, true)
      expectNoDifference(containsUnzipping, true)
      expectNoDifference($0.last, .finished(url))
      expectNoDifference($0.count { $0 == nil }, 0)
    }
  }

  @Test("Cancel Download")
  func cancelDownload() async throws {
    let metadata = try await self.modelMetadata()

    let progress = Lock([Result<CactusLanguageModel.DownloadProgress, any Error>]())
    let task = Task {
      try await CactusLanguageModel.downloadModel(
        with: metadata,
        to: self.temporaryURL(),
        onProgress: { p in progress.withLock { $0.append(p) } }
      )
    }
    await Task.yield()  // NB: Give some time for downloading to begin.
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    progress.withLock { p in
      expectNoDifference(p.last?.isCancelled, true)
    }
  }

  private func modelMetadata() async throws -> CactusLanguageModel.Metadata {
    let models = try await CactusLanguageModel.availableModels()
    return try #require(models.first { $0.slug == "qwen3-0.6" })
  }

  func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("tmp-model-\(UUID())")
  }
}

extension Result {
  fileprivate var isCancelled: Bool {
    switch self {
    case .success: false
    case .failure(let error): error is CancellationError
    }
  }
}
