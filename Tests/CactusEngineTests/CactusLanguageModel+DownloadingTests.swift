import CactusEngine
import CustomDump
import Foundation
import Testing

@Suite("CactusLanguageModel+Downloading tests")
struct CactusLanguageModelDownloadingTests {
  @Test("Task Not Finished By Default")
  func testNotFinishedByDefault() async throws {
    let task = CactusLanguageModel.downloadModelTask(
      with: try await CactusLanguageModel.testModelMetadata(),
      to: self.temporaryURL()
    )
    expectNoDifference(task.isFinished, false)
  }

  @Test("Download Model Successfully")
  func downloadModelSuccessfully() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    defer { try? FileManager.default.removeItem(at: url) }

    CactusLanguageModel.testModelDownloadProgress.withLock {
      let containsDownloading = $0.contains {
        switch $0 {
        case .success(.downloading): true
        default: false
        }
      }
      let containsUnzipping = $0.contains {
        switch $0 {
        case .success(.unzipping): true
        default: false
        }
      }
      expectNoDifference(containsDownloading, true)
      expectNoDifference(containsUnzipping, true)
      expectNoDifference(try? $0.last?.get(), .finished(url))
      expectNoDifference($0.contains { $0.isFailure }, false)
    }
  }

  @Test("Cancel Download From Concurrency Task")
  func cancelDownload() async throws {
    let progress = Lock([Result<CactusLanguageModel.DownloadProgress, any Error>]())
    let task = Task {
      try await CactusLanguageModel.downloadModel(
        with: CactusLanguageModel.testModelMetadata(),
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

  @Test("Cancel Download From Task")
  func cancelDownloadFromTask() async throws {
    let task = CactusLanguageModel.downloadModelTask(
      with: try await CactusLanguageModel.testModelMetadata(),
      to: self.temporaryURL()
    )

    let progress = Lock([Result<CactusLanguageModel.DownloadProgress, any Error>]())
    let subscription = task.onProgress { p in progress.withLock { $0.append(p) } }
    task.resume()
    await Task.yield()
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.waitForCompletion()
    }
    progress.withLock { p in
      expectNoDifference(p.last?.isCancelled, true)
    }
    expectNoDifference(task.isCancelled, true)
    expectNoDifference(task.isFinished, true)
    subscription.cancel()
  }

  private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("tmp-model-\(UUID())")
  }
}

extension Result {
  fileprivate var isFailure: Bool {
    switch self {
    case .success: false
    case .failure: true
    }
  }

  fileprivate var isCancelled: Bool {
    switch self {
    case .success: false
    case .failure(let error): error is CancellationError
    }
  }
}
