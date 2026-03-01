import Foundation
import Zip

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - Download Model

extension CactusModel {
  /// Downloads the model for the provided ``HubDownloadRequest`` to the provided destination `URL`.
  ///
  /// - Parameters:
  ///   - request: The ``HubDownloadRequest`` to download the model from.
  ///   - destination: The `URL` to download the model to.
  ///   - configuration: A `URLSessionConfiguration` for the download.
  ///   - onProgress: A callback that is invoked when progress is made towards the download.
  /// - Returns: The destination`URL` of the downloaded model.
  @discardableResult
  public static func downloadModel(
    request: PlatformDownloadRequest,
    to destination: URL,
    configuration: URLSessionConfiguration = .default,
    onProgress: @escaping @Sendable (Result<DownloadProgress, any Error>) -> Void = { _ in }
  ) async throws -> URL {
    try await Self.downloadModel(
      from: request.defaultURL,
      to: destination,
      configuration: configuration,
      onProgress: onProgress
    )
  }

  /// Downloads the model for the provided source `URL` to the provided destination `URL`.
  ///
  /// - Parameters:
  ///   - url: The source download `URL` of the model.
  ///   - destination: The `URL` to download the model to.
  ///   - configuration: A `URLSessionConfiguration` for the download.
  ///   - onProgress: A callback that is invoked when progress is made towards the download.
  /// - Returns: The destination`URL` of the downloaded model.
  @discardableResult
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

  /// Returns a ``DownloadTask`` for the model with the specified ``HubDownloadRequest``.
  ///
  /// You must manually start the download by calling ``DownloadTask/resume()``.
  ///
  /// - Parameters:
  ///   - request: The ``HubDownloadRequest`` for the model.
  ///   - destination: The `URL` to download the model to.
  ///   - configuration: A `URLSessionConfiguration` for the download.
  /// - Returns: A ``DownloadTask``.
  public static func downloadModelTask(
    request: PlatformDownloadRequest,
    to destination: URL,
    configuration: URLSessionConfiguration = .default
  ) -> DownloadTask {
    Self.downloadModelTask(
      from: request.defaultURL,
      to: destination,
      configuration: configuration
    )
  }

  /// Returns a ``DownloadTask`` for the model at the specificed source `URL`.
  ///
  /// You must manually start the download by calling ``DownloadTask/resume()``.
  ///
  /// - Parameters:
  ///   - url: The source download `URL` of the model.
  ///   - destination: The `URL` to download the model to.
  ///   - configuration: A `URLSessionConfiguration` for the download.
  /// - Returns: A ``DownloadTask``.
  public static func downloadModelTask(
    from url: URL,
    to destination: URL,
    configuration: URLSessionConfiguration = .default
  ) -> DownloadTask {
    DownloadTask(from: url, to: destination, configuration: configuration)
  }
}

// MARK: - PlatformDownloadRequest

extension CactusModel {
  /// A request to download a model from the cactus platform.
  public struct PlatformDownloadRequest: Hashable, Sendable {
    /// The quantization format of the model.
    public struct Quantization: Hashable, Sendable, RawRepresentable {
      public static let int4 = Self(rawValue: "int4")
      public static let int8 = Self(rawValue: "int8")

      public let rawValue: String

      public init(rawValue: String) {
        self.rawValue = rawValue
      }
    }

    /// The library version of the model.
    ///
    /// New constants are added to the `Version` struct whenever the weights for the cactus model
    /// format itself are changed, not the underlying version of the cactus engine itself. As such
    /// there will be gaps between version numbers, which indicates that the weights were not
    /// changed between those engine releases. When such change occurs, previous version constants
    /// will be deprecated.
    public struct Version: Hashable, Sendable, RawRepresentable {
      public static let v1_5 = Self(rawValue: "v1.5")
      public static let v1_7 = Self(rawValue: "v1.7")
      public static let v1_8 = Self(rawValue: "v1.8")
      public static let v1_9 = Self(rawValue: "v1.9")

      public let rawValue: String

      public init(rawValue: String) {
        self.rawValue = rawValue
      }
    }

    /// The pro version configuration for the model.
    public struct Pro: Hashable, Sendable, RawRepresentable {
      public static let apple = Self(rawValue: "apple")

      public let rawValue: String

      public init(rawValue: String) {
        self.rawValue = rawValue
      }
    }

    /// The model slug.
    public var slug: String

    /// The quantization format of the model.
    public var quantization: Quantization

    /// The library version of the model.
    public var version: Version

    /// The pro version configuration for the model.
    public var pro: Pro?

    /// A download URL for the model.
    public var defaultURL: URL {
      let proSuffix = self.pro.map { "-\($0.rawValue)" } ?? ""
      let filename = "\(self.slug)-\(self.quantization.rawValue)\(proSuffix).zip"
      return URL(
        string:
          "https://huggingface.co/Cactus-Compute/\(self.huggingFaceRepoName)/resolve/\(self.version.rawValue)/weights/\(filename)"
      )!
    }

    private var huggingFaceRepoName: String {
      switch self.slug {
      case "gemma-3-270m-it": "gemma-3-270m-it"
      case "functiongemma-270m-it": "functiongemma-270m-it"
      case "whisper-small": "whisper-small"
      case "whisper-medium": "whisper-medium"
      case "lfm2-350m": "LFM2-350M"
      case "lfm2-700m": "LFM2-700M"
      case "lfm2-1.2b": "LFM2-1.2B"
      case "lfm2-1.2b-rag": "LFM2-1.2B-RAG"
      case "lfm2-1.2b-tool": "LFM2-1.2B-Tool"
      case "lfm2.5-1.2b-instruct": "LFM2.5-1.2B-Instruct"
      case "lfm2.5-1.2b-thinking": "LFM2.5-1.2B-Thinking"
      case "lfm2-2.6b": "LFM2-2.6B"
      case "lfm2-vl-450m": "LFM2-VL-450M"
      case "lfm2.5-vl-1.6b": "LFM2.5-VL-1.6B"
      case "qwen3-0.6b": "Qwen3-0.6B"
      case "qwen3-embedding-0.6b": "Qwen3-Embedding-0.6B"
      case "qwen3-1.7b": "Qwen3-1.7B"
      case "nomic-embed-text-v2-moe": "nomic-embed-text-v2-moe"
      case "moonshine-base": "moonshine-base"
      case "silero-vad": "silero-vad"
      default: self.slug
      }
    }

    /// Creates a download request.
    ///
    /// - Parameters:
    ///   - slug: The model slug.
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    ///   - pro: The pro version configuration for the model.
    public init(
      slug: String,
      quantization: Quantization = .int4,
      version: Version = .v1_9,
      pro: Pro? = nil
    ) {
      self.slug = slug
      self.quantization = quantization
      self.version = version
      self.pro = pro
    }

    /// Creates a download request for the `gemma-3-270m-it` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func gemma3_270mIt(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "gemma-3-270m-it", quantization: quantization, version: version)
    }

    /// Creates a download request for the `functiongemma-270m-it` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func functiongemma270mIt(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "functiongemma-270m-it", quantization: quantization, version: version)
    }

    /// Creates a download request for the `gemma-3-1b-it` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func gemma3_1bIt(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "gemma-3-1b-it", quantization: quantization, version: version)
    }

    /// Creates a download request for the `whisper-small` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func whisperSmall(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "whisper-small", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `whisper-medium` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func whisperMedium(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "whisper-medium", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `lfm2-350m` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_350m(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-350m", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-700m` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_700m(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-700m", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-1.2b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_1_2b(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-1.2b", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-1.2b-rag` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_1_2bRag(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-1.2b-rag", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-1.2b-tool` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_1_2bTool(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-1.2b-tool", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2.5-1.2b-instruct` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_5_1_2bInstruct(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2.5-1.2b-instruct", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2.5-1.2b-thinking` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_5_1_2bThinking(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2.5-1.2b-thinking", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-2.6b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func lfm2_2_6b(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "lfm2-2.6b", quantization: quantization, version: version)
    }

    /// Creates a download request for the `lfm2-vl-450m` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func lfm2Vl_450m(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "lfm2-vl-450m", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `lfm2.5-vl-1.6b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func lfm2_5Vl_1_6b(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "lfm2.5-vl-1.6b", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `qwen3-0.6b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func qwen3_0_6b(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "qwen3-0.6b", quantization: quantization, version: version)
    }

    /// Creates a download request for the `qwen3-embedding-0.6b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func qwen3Embedding_0_6b(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "qwen3-embedding-0.6b", quantization: quantization, version: version)
    }

    /// Creates a download request for the `qwen3-1.7b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func qwen3_1_7b(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "qwen3-1.7b", quantization: quantization, version: version)
    }

    /// Creates a download request for the `nomic-embed-text-v2-moe` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func nomicEmbedTextV2Moe(quantization: Quantization = .int4, version: Version = .v1_9) -> Self {
      Self(slug: "nomic-embed-text-v2-moe", quantization: quantization, version: version)
    }

    /// Creates a download request for the `moonshine-base` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func moonshineBase(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "moonshine-base", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `parakeet-ctc-0.6b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func parakeetCtc_0_6b(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "parakeet-ctc-0.6b", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `parakeet-ctc-1.1b` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - pro: The pro version configuration for the model.
    ///   - version: The library version of the model.
    public static func parakeetCtc_1_1b(
      quantization: Quantization = .int4,
      pro: Pro? = nil,
      version: Version = .v1_9
    ) -> Self {
      Self(slug: "parakeet-ctc-1.1b", quantization: quantization, version: version, pro: pro)
    }

    /// Creates a download request for the `silero-vad` model.
    ///
    /// - Parameters:
    ///   - quantization: The quantization format of the model.
    ///   - version: The library version of the model.
    public static func sileroVad(quantization: Quantization = .int4, version: Version = .v1_7) -> Self {
      Self(slug: "silero-vad", quantization: quantization, version: version)
    }
  }
}

// MARK: - DownloadProgress

extension CactusModel {
  /// An enum representing progress on downloading a model from cactus.
  public enum DownloadProgress: Hashable, Sendable {
    /// The model is being downloaded over the network.
    case downloading(Double)

    /// The model is being unzipped.
    case unzipping(Double)

    /// The model has finished downloading and has been unzipped.
    case finished(URL)
  }
}

// MARK: - DownloadTask

extension CactusModel {
  /// A class to manage the download of a ``CactusModel``.
  public final class DownloadTask: Sendable {
    private let task: URLSessionDownloadTask
    private let delegate: Delegate

    /// The destination `URL` of the downloaded model.
    public let destination: URL

    /// Whether or not the download has been cancelled.
    public var isCancelled: Bool {
      self.delegate.state.withLock {
        $0.observable.finalResult?.failure is CancellationError
      }
    }

    /// Whether or not the download is paused.
    public var isPaused: Bool {
      self.delegate.state.withLock { $0.observable.isPaused }
    }

    /// Whether or not the download has ended.
    public var isFinished: Bool {
      self.delegate.state.withLock { $0.observable.finalResult != nil }
    }

    /// The current ``CactusModel/DownloadProgress``.
    public var currentProgress: DownloadProgress {
      self.delegate.state.withLock { $0.observable.progress }
    }

    /// The error of this task if the download failed.
    public var error: (any Error)? {
      self.delegate.state.withLock { $0.observable.finalResult?.failure }
    }

    init(
      from url: URL,
      to destination: URL,
      configuration: URLSessionConfiguration
    ) {
      let delegate = Delegate(destination: destination)
      let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
      self.task = session.downloadTask(with: url)
      self.destination = destination
      self.delegate = delegate
    }

    /// Waits for completion of the download.
    ///
    /// - Returns: The destination`URL` of the downloaded model.
    @discardableResult
    public func waitForCompletion() async throws -> URL {
      let state = Lock<WaitForCompletionState>(WaitForCompletionState())
      return try await withTaskCancellationHandler {
        try await withUnsafeThrowingContinuation { continuation in
          state.withLock { innerState in
            if let finalResult = self.delegate.state.withLock(\.observable.finalResult) {
              continuation.resume(with: finalResult)
              return
            }
            innerState.continuation = continuation
            innerState.subscription = self.onProgress { result in
              state.withLock { state in
                switch result {
                case .success(.finished(let url)):
                  state.resume(with: .success(url))
                case .failure(let error):
                  state.resume(with: .failure(error))
                default:
                  break
                }
              }
            }
          }
        }
      } onCancel: {
        state.withLock { $0.resume(with: .failure(CancellationError())) }
      }
    }

    private struct WaitForCompletionState {
      var continuation: UnsafeContinuation<URL, any Error>?
      var subscription: CactusSubscription?

      mutating func resume(with result: Result<URL, any Error>) {
        self.continuation?.resume(with: result)
        self.continuation = nil
      }
    }

    /// Adds a handler to observe the progress of the download.
    ///
    /// - Parameter handler: The handler.
    /// - Returns: A ``CactusSubscription``.
    public func onProgress(
      _ handler: @escaping @Sendable (Result<DownloadProgress, any Error>) -> Void
    ) -> CactusSubscription {
      let id = self.delegate.state.withLock { $0.onProgress(handler) }
      return CactusSubscription { [weak self] in
        self?.delegate.state.withLock { $0.clearProgress(id) }
      }
    }

    /// Resumes the download from a paused state.
    public func resume() {
      self.delegate.state.withLock { $0.observable.isPaused = false }
      self.task.resume()
    }

    /// Cancels the download.
    public func cancel() {
      self.task.cancel()
    }

    /// Pauses the download.
    public func pause() {
      self.delegate.state.withLock { $0.observable.isPaused = true }
      self.task.suspend()
    }
  }
}

extension CactusModel.DownloadTask {
  private final class Delegate: NSObject, URLSessionDownloadDelegate, Sendable {
    struct State {
      let observable = ObservableState()
      private(set) var callbacks = [
        Int: @Sendable (Result<CactusModel.DownloadProgress, any Error>) -> Void
      ]()
      private var progressId = 0

      mutating func onProgress(
        _ handler:
          @escaping @Sendable (Result<CactusModel.DownloadProgress, any Error>) -> Void
      ) -> Int {
        defer { self.progressId += 1 }
        self.callbacks[self.progressId] = handler
        return self.progressId
      }

      mutating func clearProgress(_ id: Int) {
        self.callbacks.removeValue(forKey: id)
      }

      mutating func sendProgress(
        _ progress: Result<CactusModel.DownloadProgress, any Error>
      ) {
        if case .success(let progress) = progress {
          self.observable.progress = progress
        }
        self.callbacks.values.forEach { $0(progress) }
      }
    }

    let state = RecursiveLock(State())
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
      self.state.withLock {
        $0.sendProgress(.success(.downloading(downloadTask.progress.fractionCompleted)))
      }
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didFinishDownloadingTo location: URL
    ) {
      do {
        self.state.withLock { $0.sendProgress(.success(.downloading(1))) }
        Zip.addCustomFileExtension("tmp")
        try Zip.unzipFile(location, destination: self.destination, overwrite: true) { progress in
          self.state.withLock { $0.sendProgress(.success(.unzipping(progress))) }
        }
        self.state.withLock {
          $0.observable.finalResult = .success(self.destination)
          $0.sendProgress(.success(.finished(self.destination)))
        }
      } catch {
        self.state.withLock {
          $0.observable.finalResult = .failure(error)
          $0.sendProgress(.failure(error))
        }
      }
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      guard let error else { return }
      if (error as? URLError)?.code == .cancelled {
        self.state.withLock {
          $0.observable.finalResult = .failure(CancellationError())
          $0.sendProgress(.failure(CancellationError()))
        }
      } else {
        self.state.withLock {
          $0.observable.finalResult = .failure(error)
          $0.sendProgress(.failure(error))
        }
      }
    }
  }
}

extension CactusModel.DownloadTask {
  fileprivate final class ObservableState {
    private let observationRegistrar = _ObservationRegistrar()

    private var _finalResult: Result<URL, any Error>?
    var finalResult: Result<URL, any Error>? {
      get {
        self.observationRegistrar.access(self, keyPath: \.finalResult)
        return self._finalResult
      }
      set {
        self.observationRegistrar.withMutation(of: self, keyPath: \.finalResult) {
          self._finalResult = newValue
        }
      }
    }

    private var _isPaused = true
    var isPaused: Bool {
      get {
        self.observationRegistrar.access(self, keyPath: \.isPaused)
        return self._isPaused
      }
      set {
        self.observationRegistrar.withMutation(of: self, keyPath: \.isPaused) {
          self._isPaused = newValue
        }
      }
    }

    private var _progress = CactusModel.DownloadProgress.downloading(0)
    var progress: CactusModel.DownloadProgress {
      get {
        self.observationRegistrar.access(self, keyPath: \.progress)
        return self._progress
      }
      set {
        self.observationRegistrar.withMutation(of: self, keyPath: \.progress) {
          self._progress = newValue
        }
      }
    }
  }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModel.DownloadTask.ObservableState: _Observable {}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusModel.DownloadTask: _Observable {}
