import CXXCactusShims
import Foundation

// MARK: - CactusVADSession

/// A concurrency-safe session for voice activity detection.
///
/// This type serializes access to an underlying ``CactusModel`` actor and exposes a
/// one-shot async API for VAD inference.
public final class CactusVADSession: Sendable {
  /// The underlying language model actor.
  public let languageModelActor: CactusModelActor

  /// Creates a VAD session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: consuming sending CactusModel) {
    self.languageModelActor = CactusModelActor(model: model)
  }

  /// Creates a VAD session from an existing language model actor.
  ///
  /// - Parameter model: The underlying language model actor.
  public init(model: CactusModelActor) {
    self.languageModelActor = model
  }

  /// Creates a VAD session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local model URL.
  public convenience init(from url: URL) throws {
    let languageModelActor = try CactusModelActor(from: url)
    self.init(model: languageModelActor)
  }

  /// Creates a VAD session from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  ///   - modelURL: The model URL used to locate supporting model files.
  public convenience init(
    model: consuming sending cactus_model_t,
    modelURL: URL
  ) throws {
    let languageModelActor = try CactusModelActor(
      model: model,
      modelURL: modelURL
    )
    self.init(model: languageModelActor)
  }
}

// MARK: - Public API

extension CactusVADSession {
  /// Performs voice activity detection and returns parsed speech segments.
  ///
  /// - Parameter request: The voice activity detection request.
  /// - Returns: The parsed VAD output.
  public func vad(request: CactusVAD.Request) async throws -> CactusVAD {
    if let samplingRate = request.samplingRate {
      precondition(samplingRate > 0, "Sampling rate must be greater than 0.")
    }
    let state = VADContinuationState()
    let options = CactusModel.VADOptions(request: request)

    return try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { continuation in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
          return
        }
        state.setContinuation(continuation)
        let task = Task {
          let result: Result<CactusVAD, any Error>
          do {
            try Task.checkCancellation()
            let rawResult = try await self.performVAD(
              request: request,
              options: options
            )
            result = .success(CactusVAD(rawResult: rawResult, samplingRate: request.samplingRate))
          } catch {
            result = .failure(error)
          }
          state.finish(with: result)
        }
        state.setTask(task)
      }
    } onCancel: {
      state.cancel()
    }
  }
}

// MARK: - Helpers

extension CactusVADSession {
  private final class VADContinuationState: @unchecked Sendable {
    private struct State {
      var continuation: UnsafeContinuation<CactusVAD, any Error>?
      var task: Task<Void, Never>?
    }

    private let state = Lock(State())

    func setContinuation(_ continuation: UnsafeContinuation<CactusVAD, any Error>) {
      self.state.withLock { $0.continuation = continuation }
    }

    func setTask(_ task: Task<Void, Never>) {
      var shouldCancel = false
      self.state.withLock { state in
        if state.continuation == nil {
          shouldCancel = true
          return
        }
        state.task = task
      }
      if shouldCancel {
        task.cancel()
      }
    }

    func finish(with result: Result<CactusVAD, any Error>) {
      var continuation: UnsafeContinuation<CactusVAD, any Error>?
      self.state.withLock { state in
        continuation = state.continuation
        state.continuation = nil
        state.task = nil
      }
      continuation?.resume(with: result)
    }

    func cancel() {
      var continuation: UnsafeContinuation<CactusVAD, any Error>?
      var task: Task<Void, Never>?
      self.state.withLock { state in
        continuation = state.continuation
        task = state.task
        state.continuation = nil
        state.task = nil
      }

      task?.cancel()
      continuation?.resume(throwing: CancellationError())
    }
  }

  private func performVAD(
    request: CactusVAD.Request,
    options: CactusModel.VADOptions
  ) async throws -> CactusModel.VADResult {
    if let audioURL = request.content.audioURL {
      return try await languageModelActor.vad(
        audio: audioURL,
        options: options,
        maxBufferSize: request.maxBufferSize
      )
    }

    if let pcmBytes = request.content.pcmBytes {
      return try await languageModelActor.vad(
        pcmBuffer: pcmBytes,
        options: options,
        maxBufferSize: request.maxBufferSize
      )
    }

    return try await languageModelActor.vad(
      pcmBuffer: [],
      options: options,
      maxBufferSize: request.maxBufferSize
    )
  }
}
