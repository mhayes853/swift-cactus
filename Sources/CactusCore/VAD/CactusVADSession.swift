import CXXCactusShims
import Foundation

// MARK: - CactusVADSession

/// A concurrency-safe session for voice activity detection.
public final class CactusVADSession: Sendable {
  /// The underlying model actor.
  public let modelActor: CactusModelActor

  /// Creates a VAD session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: consuming sending CactusModel) {
    self.modelActor = CactusModelActor(model: model)
  }

  /// Creates a VAD session from an existing language model actor.
  ///
  /// - Parameter model: The underlying language model actor.
  public init(model: CactusModelActor) {
    self.modelActor = model
  }

  /// Creates a VAD session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local model URL.
  public convenience init(from url: URL) throws {
    let modelActor = try CactusModelActor(from: url)
    self.init(model: modelActor)
  }

  /// Creates a VAD session from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  public convenience init(model: consuming sending cactus_model_t) {
    let modelActor = CactusModelActor(model: model)
    self.init(model: modelActor)
  }
}

// MARK: - Public API

extension CactusVADSession {
  /// Performs voice activity detection and returns parsed speech segments.
  ///
  /// - Parameter request: The voice activity detection request.
  /// - Returns: The parsed VAD output.
  public func vad(request: CactusVAD.Request) async throws -> CactusVAD {
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
      return try await modelActor.vad(
        audio: audioURL,
        options: options,
        maxBufferSize: request.maxBufferSize
      )
    }

    if let pcmBytes = request.content.pcmBytes {
      return try await modelActor.vad(
        pcmBuffer: pcmBytes,
        options: options,
        maxBufferSize: request.maxBufferSize
      )
    }

    return try await modelActor.vad(
      pcmBuffer: [],
      options: options,
      maxBufferSize: request.maxBufferSize
    )
  }
}
