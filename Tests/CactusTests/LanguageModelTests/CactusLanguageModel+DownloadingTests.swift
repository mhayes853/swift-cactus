import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusLanguageModelDownloading tests` {
  @Test
  func `Task Not Finished By Default`() async throws {
    let task = CactusLanguageModel.downloadModelTask(
      from: CactusLanguageModel.modelDownloadURL(slug: CactusLanguageModel.testModelSlug),
      to: self.temporaryURL()
    )
    expectNoDifference(task.isFinished, false)
  }

  @Test
  func `Download Model Successfully`() async throws {
    let progress = Lock([Result<CactusLanguageModel.DownloadProgress, any Error>]())
    let observedProgress = Lock([CactusLanguageModel.DownloadProgress]())
    let observedIsPaused = Lock([Bool]())

    let task = CactusLanguageModel.downloadModelTask(
      slug: CactusLanguageModel.testModelSlug,
      to: self.temporaryURL()
    )

    var token: ObserveToken?
    var token2: ObserveToken?
    defer {
      token?.cancel()
      token2?.cancel()
    }
    if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
      token = observe {
        observedProgress.withLock { $0.append(task.currentProgress) }
      }
      token2 = observe {
        observedIsPaused.withLock { $0.append(task.isPaused) }
      }
    }

    let subscription = task.onProgress { result in
      progress.withLock { $0.append(result) }
    }
    defer { subscription.cancel() }

    task.resume()
    let url = try await task.waitForCompletion()

    progress.withLock {
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

    if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
      observedProgress.withLock {
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
      }
      observedIsPaused.withLock {
        expectNoDifference($0, [true, false])
      }
    }

    try FileManager.default.removeItem(at: url)
  }

  @Test
  func `Cancel Download From Concurrency Task`() async throws {
    let task = Task {
      try await CactusLanguageModel.downloadModel(
        from: CactusLanguageModel.modelDownloadURL(slug: CactusLanguageModel.testModelSlug),
        to: self.temporaryURL()
      )
    }
    try await Task.sleep(nanoseconds: nanosecondsPerSecond)  // NB: Give some time for downloading to begin.
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test
  func `Cancel Download From Task`() async throws {
    let task = CactusLanguageModel.downloadModelTask(
      from: CactusLanguageModel.modelDownloadURL(slug: CactusLanguageModel.testModelSlug),
      to: self.temporaryURL()
    )

    let progress = Lock([Result<CactusLanguageModel.DownloadProgress, any Error>]())
    let subscription = task.onProgress { p in progress.withLock { $0.append(p) } }
    task.resume()
    try await Task.sleep(nanoseconds: nanosecondsPerSecond)  // NB: Give some time for downloading to begin.
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
