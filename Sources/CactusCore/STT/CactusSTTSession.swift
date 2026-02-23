import CXXCactusShims
import Foundation

// MARK: - CactusSTTSession

/// A concurrency-safe session for speech-to-text transcription.
///
/// This type serializes access to an underlying ``CactusLanguageModel`` and exposes
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
  /// The underlying language model actor.
  public let languageModelActor: CactusLanguageModelActor

  /// Creates a transcription session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: sending CactusLanguageModel) {
    self.languageModelActor = CactusLanguageModelActor(model: model)
  }

  /// Creates a transcription session from an existing language model actor.
  ///
  /// - Parameter actor: The underlying language model actor.
  public init(model: CactusLanguageModelActor) {
    self.languageModelActor = model
  }

  /// Creates a transcription session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local model URL.
  ///   - modelSlug: An optional model slug override.
  public convenience init(from url: URL, modelSlug: String? = nil) throws {
    let model = try CactusLanguageModel(from: url, modelSlug: modelSlug)
    self.init(model: model)
  }

  /// Creates a transcription session from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  ///   - modelURL: The model URL used to construct model configuration.
  ///   - modelSlug: An optional model slug override.
  ///   - isModelPointerManaged: Whether the pointer should be destroyed by the model instance.
  public convenience init(
    model: sending cactus_model_t,
    modelURL: URL,
    modelSlug: String? = nil,
    isModelPointerManaged: Bool = false
  ) throws {
    let languageModel = try CactusLanguageModel(
      model: model,
      configuration: CactusLanguageModel.Configuration(modelURL: modelURL, modelSlug: modelSlug),
      isModelPointerManaged: isModelPointerManaged
    )
    self.init(model: languageModel)
  }
}

// MARK: - Public API

extension CactusSTTSession {
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
    let options = CactusLanguageModel.Transcription.Options(request: request)
    let maxBufferSize = request.maxBufferSize

    let stream = CactusInferenceStream<CactusTranscription> { [weak self] continuation in
      guard self != nil else { throw CancellationError() }

      let modelStopper = await languageModelActor.withLanguageModel {
        CactusLanguageModelStopper(model: $0)
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
  public func transcribe(
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

/// An error thrown by ``CactusSTTSession`` stream APIs.
public struct CactusTranscriptionStreamError: Error, Hashable, Sendable {
  /// A human-readable description of the failure.
  public let message: String

  private init(message: String) {
    self.message = message
  }
}
