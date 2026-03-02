import CXXCactusShims
import Foundation

// MARK: - CactusSTTSession

/// A concurrency-safe session for speech-to-text transcription.
///
/// ```swift
/// import Cactus
///
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(
///   for: .parakeetCtc_1_1b()
/// )
///
/// let session = try CactusSTTSession(from: modelURL)
///
/// // WAV File
/// let request = CactusTranscription.Request(
///   prompt: .default,
///   content: .audio(.documentsDirectory.appending(path: "audio.wav"))
/// )
/// let transcription = try await session.transcribe(request: request)
/// print(transcription.content)
///
/// // PCM Buffer
/// let pcmBytes: [UInt8] = [...]
/// let request = CactusTranscription.Request(
///   prompt: .default,
///   content: .pcm(pcmBytes)
/// )
/// let transcription = try await session.transcribe(request: request)
/// print(transcription.content)
///
/// // AVFoundation (Apple Platforms Only)
/// import AVFoundation
///
/// let buffer: AVAudioPCMBuffer = ...
/// let request = CactusTranscription.Request(
///   prompt: .default,
///   content: try .pcm(buffer)
/// )
/// let transcription = try await session.transcribe(request: request)
/// print(transcription.content)
/// ```
public final class CactusSTTSession: Sendable {
  /// The underlying model actor.
  public let modelActor: CactusModelActor

  /// Creates a transcription session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: consuming sending CactusModel) {
    self.modelActor = CactusModelActor(model: model)
  }

  /// Creates a transcription session from an existing language model actor.
  ///
  /// - Parameter model: The underlying language model actor.
  public init(model: CactusModelActor) {
    self.modelActor = model
  }

  /// Creates a transcription session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local model URL.
  public convenience init(from url: URL) throws {
    let modelActor = try CactusModelActor(from: url)
    self.init(model: modelActor)
  }

  /// Creates a transcription session from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  public convenience init(model: consuming sending cactus_model_t) {
    let modelActor = CactusModelActor(model: model)
    self.init(model: modelActor)
  }
}

// MARK: - Public API

extension CactusSTTSession {
  /// Creates a transcription stream for the provided request.
  ///
  /// ```swift
  /// let session = try CactusSTTSession(from: modelURL)
  ///
  /// let request = CactusTranscription.Request(
  ///   prompt: .default,
  ///   content: .audio(.documentsDirectory.appending(path: "audio.wav"))
  /// )
  /// let stream = try session.transcriptionStream(request: request)
  /// for await token in stream.tokens {
  ///   print(token.stringValue, token.tokenId, token.generationStreamId)
  /// }
  ///
  /// let transcription = try await stream.collectResponse()
  /// print(transcription.content)
  /// ```
  ///
  /// - Parameter request: The transcription request.
  /// - Returns: A stream that yields transcription tokens and final output.
  public func transcriptionStream(
    request: CactusTranscription.Request
  ) throws -> CactusInferenceStream<CactusTranscription> {
    let messageStreamID = CactusGenerationID()
    let modelActor = self.modelActor
    let options = CactusModel.Transcription.Options(request: request)
    let maxBufferSize = request.maxBufferSize

    let stream = CactusInferenceStream<CactusTranscription> { [weak self] continuation in
      guard self != nil else { throw CancellationError() }

      let modelStopper = await modelActor.withModelPointer {
        CactusModelStopper(modelPointer: $0)
      }

      let modelTranscription = try await withTaskCancellationHandler {
        if let audioURL = request.content.audioURL {
          return try await modelActor.transcribe(
            audio: audioURL,
            prompt: request.prompt.description,
            options: options,
            maxBufferSize: maxBufferSize
          ) { stringValue, tokenId in
            continuation.yield(
              token: CactusStreamedToken(
                generationStreamId: messageStreamID,
                stringValue: stringValue,
                tokenId: tokenId
              )
            )
          }
        }

        if let pcmBytes = request.content.pcmBytes {
          return try await modelActor.transcribe(
            buffer: pcmBytes,
            prompt: request.prompt.description,
            options: options,
            transcriptionMaxBufferSize: maxBufferSize
          ) { stringValue, tokenId in
            continuation.yield(
              token: CactusStreamedToken(
                generationStreamId: messageStreamID,
                stringValue: stringValue,
                tokenId: tokenId
              )
            )
          }
        }

        return try await modelActor.transcribe(
          buffer: [],
          prompt: request.prompt.description,
          options: options,
          transcriptionMaxBufferSize: maxBufferSize
        ) { stringValue, tokenId in
          continuation.yield(
            token: CactusStreamedToken(
              generationStreamId: messageStreamID,
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
