import Foundation
import Zip

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - Download Model

extension CactusLanguageModel {
  public static func modelDownloadURL(slug: String) -> URL {
    CactusSupabaseClient.shared.modelDownloadURL(for: slug)
  }

  public static func downloadModel(
    from url: URL,
    to destination: URL,
    configuration: URLSessionConfiguration = .default,
    onProgress: @escaping @Sendable (Result<DownloadProgress, any Error>) -> Void = { _ in }
  ) async throws -> URL {
    let task = Self.downloadModelTask(from: url, to: destination, configuration: configuration)
    let subscription = task.onProgress(onProgress)
    defer { subscription.cancel() }
    task.resume()
    return try await withTaskCancellationHandler {
      try await task.waitForCompletion()
    } onCancel: {
      task.cancel()
    }
  }

  public static func downloadModelTask(
    from url: URL,
    to destination: URL,
    configuration: URLSessionConfiguration = .default
  ) -> DownloadTask {
    DownloadTask(from: url, to: destination, configuration: configuration)
  }
}

// MARK: - DownloadProgress

extension CactusLanguageModel {
  public enum DownloadProgress: Hashable, Sendable {
    case downloading(Double)
    case unzipping(Double)
    case finished(URL)
  }
}

// MARK: - DownloadTask

extension CactusLanguageModel {
  public final class DownloadTask: Sendable {
    private let task: URLSessionDownloadTask
    private let delegate: Delegate

    init(
      from url: URL,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) {
      let delegate = Delegate(destination: destination)
      let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
      self.task = session.downloadTask(with: url)
      self.delegate = delegate
    }

    public var isCancelled: Bool {
      self.delegate.state.withLock { $0.isCancelled }
    }

    public var isPaused: Bool {
      self.delegate.state.withLock { $0.isPaused }
    }

    public var isFinished: Bool {
      self.delegate.state.withLock { $0.isFinished || $0.isCancelled }
    }

    @discardableResult
    public func waitForCompletion() async throws -> URL {
      let state = Lock<(UnsafeContinuation<URL, any Error>?, CactusSubscription?)>((nil, nil))
      return try await withTaskCancellationHandler {
        try await withUnsafeThrowingContinuation { continuation in
          state.withLock {
            $0.0 = continuation
            $0.1 = self.onProgress { result in
              switch result {
              case .success(.finished(let url)):
                continuation.resume(returning: url)
              case .failure(let error):
                continuation.resume(throwing: error)
              default:
                break
              }
            }
          }
        }
      } onCancel: {
        state.withLock { $0.0?.resume(throwing: CancellationError()) }
      }
    }

    public func onProgress(
      _ handler: @escaping @Sendable (Result<DownloadProgress, any Error>) -> Void
    ) -> CactusSubscription {
      let id = self.delegate.state.withLock { $0.onProgress(handler) }
      return CactusSubscription { [weak self] in
        self?.delegate.state.withLock { $0.clearProgress(id) }
      }
    }

    public func resume() {
      self.delegate.state.withLock { $0.isPaused = false }
      self.task.resume()
    }

    public func cancel() {
      self.delegate.state.withLock { $0.isCancelled = true }
      self.task.cancel()
    }

    public func pause() {
      self.delegate.state.withLock { $0.isPaused = true }
      self.task.suspend()
    }
  }
}

extension CactusLanguageModel.DownloadTask {
  private final class Delegate: NSObject, URLSessionDownloadDelegate, Sendable {
    struct State {
      var isFinished = false
      var isCancelled = false
      var isPaused = false
      private(set) var callbacks = [
        Int: @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void
      ]()
      private var progressId = 0

      mutating func onProgress(
        _ handler:
          @escaping @Sendable (Result<CactusLanguageModel.DownloadProgress, any Error>) -> Void
      ) -> Int {
        defer { self.progressId += 1 }
        self.callbacks[self.progressId] = handler
        return self.progressId
      }

      mutating func clearProgress(_ id: Int) {
        self.callbacks.removeValue(forKey: id)
      }
    }

    let state = Lock(State())
    let destination: URL

    init(destination: URL) {
      self.destination = destination
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didWriteData bytesWritten: Int64,
      totalBytesWritten: Int64,
      totalBytesExpectedToWrite: Int64
    ) {
      self.sendProgress(.success(.downloading(downloadTask.progress.fractionCompleted)))
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didFinishDownloadingTo location: URL
    ) {
      do {
        self.sendProgress(.success(.downloading(1)))
        Zip.addCustomFileExtension("tmp")
        try Zip.unzipFile(location, destination: self.destination, overwrite: true) {
          self.sendProgress(.success(.unzipping($0)))
        }
        self.state.withLock { $0.isFinished = true }
        self.sendProgress(.success(.finished(self.destination)))
      } catch {
        self.sendProgress(.failure(error))
      }
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      guard let error else { return }
      if (error as? URLError)?.code == .cancelled {
        self.sendProgress(.failure(CancellationError()))
      } else {
        self.sendProgress(.failure(error))
      }
    }

    private func sendProgress(
      _ progress: Result<CactusLanguageModel.DownloadProgress, any Error>
    ) {
      self.state.withLock { state in
        state.callbacks.values.forEach { $0(progress) }
      }
    }
  }
}
