import CXXCactusShims
import Foundation

// MARK: - CactusSTTSession

/// A concurrency-safe session for speech-to-text transcription.
///
/// This type serializes access to an underlying ``CactusModel`` and exposes
/// modern stream and async/await APIs built on top of ``CactusInferenceStream``.
///
/// ```swift
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .whisperSmall())
/// let session = try CactusSTTSession(from: modelURL)
///
/// let request = CactusTranscription.Request(
///   language: .english,
///   includeTimestamps: false,
///   content: .audio(audioURL)
/// )
///
/// let transcription = try await session.transcribe(request: request)
/// ```
public final class CactusSTTSession: Sendable {
  private let state: Lock<State>

  private struct State {
    var activeStreamStopper: (@Sendable () -> Void)?
  }

  /// The underlying language model actor.
  public let languageModelActor: CactusModelActor

  /// Creates a transcription session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: consuming sending CactusModel) {
    self.state = Lock(State(activeStreamStopper: nil))
    self.languageModelActor = CactusModelActor(model: model)
  }

  /// Creates a transcription session from an existing language model actor.
  ///
  /// - Parameter actor: The underlying language model actor.
  public init(model: CactusModelActor) {
    self.state = Lock(State(activeStreamStopper: nil))
    self.languageModelActor = model
  }

  /// Creates a transcription session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local model URL.
  public convenience init(from url: URL) throws {
    let languageModelActor = try CactusModelActor(from: url)
    self.init(model: languageModelActor)
  }

  /// Creates a transcription session from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  public convenience init(model: consuming sending cactus_model_t) {
    let languageModelActor = CactusModelActor(model: model)
    self.init(model: languageModelActor)
  }
}

// MARK: - Public API

extension CactusSTTSession {
  /// Stops any active transcription on the underlying language model.
  nonisolated(nonsending) public func stop() async {
    self.stopActiveStreamIfNecessary()
    await self.languageModelActor.stop()
  }

  /// Creates a transcription stream for the provided request.
  ///
  /// ```swift
  /// let stream = try session.transcriptionStream(request: request)
  ///
  /// var tokenText = ""
  /// for try await token in stream.tokens {
  ///   tokenText += token.stringValue
  /// }
  ///
  /// let transcription = try await stream.collectResponse()
  /// ```
  ///
  /// - Parameter request: The transcription request.
  /// - Returns: A stream that yields transcription tokens and final output.
  public func transcriptionStream(
    request: CactusTranscription.Request
  ) throws -> CactusInferenceStream<CactusTranscription> {
    let messageStreamID = CactusGenerationID()
    let languageModelActor = self.languageModelActor
    let options = CactusModel.Transcription.Options(request: request)
    let maxBufferSize = request.maxBufferSize

    let stream = CactusInferenceStream<CactusTranscription> { [weak self] continuation in
      guard let self else { throw CancellationError() }
      defer { self.endStreaming() }

      let modelStopper = await languageModelActor.withModelPointer {
        CactusModelStopper(modelPointer: $0)
      }

      let modelTranscription = try await withTaskCancellationHandler {
        if let audioURL = request.content.audioURL {
          return try await languageModelActor.transcribe(
            audio: audioURL,
            prompt: request.prompt.description,
            options: options,
            maxBufferSize: maxBufferSize
          ) { stringValue, tokenId in
            continuation.yield(
              token: CactusStreamedToken(
                messageStreamId: messageStreamID,
                stringValue: stringValue,
                tokenId: tokenId
              )
            )
          }
        }

        if let pcmBytes = request.content.pcmBytes {
          return try await languageModelActor.transcribe(
            buffer: pcmBytes,
            prompt: request.prompt.description,
            options: options,
            transcriptionMaxBufferSize: maxBufferSize
          ) { stringValue, tokenId in
            continuation.yield(
              token: CactusStreamedToken(
                messageStreamId: messageStreamID,
                stringValue: stringValue,
                tokenId: tokenId
              )
            )
          }
        }

        return try await languageModelActor.transcribe(
          buffer: [],
          prompt: request.prompt.description,
          options: options,
          transcriptionMaxBufferSize: maxBufferSize
        ) { stringValue, tokenId in
          continuation.yield(
            token: CactusStreamedToken(
              messageStreamId: messageStreamID,
              stringValue: stringValue,
              tokenId: tokenId
            )
          )
        }
      } onCancel: {
        modelStopper.stop()
      }

      return CactusTranscription(id: messageStreamID, transcription: modelTranscription)
    }

    self.registerActiveStreamStopper(stream)
    return stream
  }

  /// Performs a transcription and returns its final parsed output.
  ///
  /// ```swift
  /// let transcription = try await session.transcribe(request: request)
  /// ```
  ///
  /// - Parameter request: The transcription request.
  /// - Returns: The final parsed transcription.
  nonisolated(nonsending) public func transcribe(
    request: CactusTranscription.Request
  ) async throws -> CactusTranscription {
    let stream = try self.transcriptionStream(request: request)
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }
}

// MARK: - Helpers

extension CactusSTTSession {
  private func registerActiveStreamStopper<Output>(_ stream: CactusInferenceStream<Output>)
  where Output: Sendable {
    self.state.withLock { $0.activeStreamStopper = { stream.stop() } }
  }

  private func stopActiveStreamIfNecessary() {
    let activeStreamStopper = self.state.withLock { state in
      let stopper = state.activeStreamStopper
      state.activeStreamStopper = nil
      return stopper
    }
    activeStreamStopper?()
  }

  private func endStreaming() {
    self.state.withLock { $0.activeStreamStopper = nil }
  }
}
