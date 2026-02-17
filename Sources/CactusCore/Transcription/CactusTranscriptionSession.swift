import CXXCactusShims
import Foundation

// MARK: - CactusTranscriptionSession

/// A concurrency-safe session for speech-to-text transcription.
///
/// This type serializes access to an underlying ``CactusLanguageModel`` and exposes
/// modern stream and async/await APIs built on top of ``CactusInferenceStream``.
///
/// ```swift
/// let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .whisperSmall())
/// let session = try CactusTranscriptionSession(from: modelURL)
///
/// let request = CactusTranscription.Request(
///   language: .english,
///   includeTimestamps: false,
///   content: .audio(audioURL)
/// )
///
/// let transcription = try await session.transcribe(request: request)
/// ```
public final class CactusTranscriptionSession: @unchecked Sendable {
  private let observationRegistrar = _ObservationRegistrar()
  private let state = Lock(State())
  private let modelActor: ModelActor
  private let modelStopper: CactusLanguageModelStopper

  private struct State {
    var activeStreamID: UUID?
    var activeStreamFinishedSubscription: CactusSubscription?
  }

  /// Whether a transcription is currently in progress.
  public var isTranscribing: Bool {
    self.observationRegistrar.access(self, keyPath: \.isTranscribing)
    return self.state.withLock { $0.activeStreamID != nil }
  }

  /// Creates a transcription session from an existing language model.
  ///
  /// - Parameter model: The underlying language model.
  public init(model: sending CactusLanguageModel) {
    self.modelStopper = CactusLanguageModelStopper(model: model.model)
    self.modelActor = ModelActor(model: model)
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

extension CactusTranscriptionSession {
  /// Creates a transcription stream for the provided request.
  ///
  /// ```swift
  /// let stream = try session.stream(request: request)
  ///
  /// var tokenText = ""
  /// for try await token in stream.tokens {
  ///   tokenText += token.stringValue
  /// }
  ///
  /// let response = try await stream.streamResponse()
  /// let transcription = response.output
  /// ```
  ///
  /// - Parameters:
  ///   - request: The transcription request.
  ///   - options: Inference options used by the model.
  /// - Returns: A stream that yields transcription tokens and final output.
  public func stream(
    request: CactusTranscription.Request,
    options: CactusLanguageModel.InferenceOptions? = nil
  ) throws -> CactusInferenceStream<CactusTranscription> {
    let streamID = try self.beginTranscribing()

    let messageStreamID = CactusMessageID()
    let modelActor = self.modelActor
    let modelStopper = self.modelStopper

    let stream = CactusInferenceStream<CactusTranscription> { [weak self] continuation in
      guard let self else { throw CancellationError() }
      defer { self.endTranscribing(streamID: streamID) }

      let modelTranscription = try await withTaskCancellationHandler {
        try await modelActor.transcribe(
          request: request,
          options: options ?? CactusLanguageModel.InferenceOptions(),
          onToken: { stringValue, tokenId in
            continuation.yield(
              token: CactusStreamedToken(
                messageStreamId: messageStreamID,
                stringValue: stringValue,
                tokenId: tokenId
              )
            )
          }
        )
      } onCancel: {
        modelStopper.stop()
      }

      return CactusInferenceStream<CactusTranscription>
        .Response(
          output: CactusTranscription(rawResponse: modelTranscription.response),
          metrics: CactusMessageMetric(transcription: modelTranscription)
        )
    }

    let finishedSubscription = stream.onToken(perform: { _ in }) { [weak self] _ in
      self?.endTranscribing(streamID: streamID)
    }
    self.setFinishedSubscription(finishedSubscription, for: streamID)
    return stream
  }

  /// Performs a transcription and returns its final parsed output.
  ///
  /// ```swift
  /// let transcription = try await session.transcribe(
  ///   request: request,
  ///   options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
  /// )
  /// _ = transcription
  /// ```
  ///
  /// - Parameters:
  ///   - request: The transcription request.
  ///   - options: Inference options used by the model.
  /// - Returns: The final parsed transcription.
  public func transcribe(
    request: CactusTranscription.Request,
    options: CactusLanguageModel.InferenceOptions? = nil
  ) async throws -> CactusTranscription {
    let stream = try self.stream(request: request, options: options)
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }

  /// Provides temporary access to the underlying language model.
  ///
  /// ```swift
  /// let slug = await session.withModel { model in
  ///   model.configuration.modelSlug
  /// }
  /// ```
  ///
  /// - Parameter operation: An operation to run with the model.
  /// - Returns: The operation return value.
  public func withModel<T: Sendable, E: Error>(
    _ operation: @Sendable (CactusLanguageModel) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try await self.modelActor.withModel(operation)
  }
}

// MARK: - State

extension CactusTranscriptionSession {
  private func beginTranscribing() throws -> UUID {
    let streamID = UUID()
    try self.observationRegistrar.withMutation(of: self, keyPath: \.isTranscribing) {
      try self.state.withLock { state in
        guard state.activeStreamID == nil else {
          throw CactusTranscriptionStreamError.alreadyTranscribing
        }
        state.activeStreamID = streamID
        state.activeStreamFinishedSubscription = nil
      }
    }
    return streamID
  }

  private func setFinishedSubscription(_ subscription: CactusSubscription, for streamID: UUID) {
    var shouldCancel = false
    self.state.withLock { state in
      if state.activeStreamID == streamID {
        state.activeStreamFinishedSubscription = subscription
      } else {
        shouldCancel = true
      }
    }
    if shouldCancel {
      subscription.cancel()
    }
  }

  private func endTranscribing(streamID: UUID) {
    var subscription: CactusSubscription?
    self.observationRegistrar.withMutation(of: self, keyPath: \.isTranscribing) {
      self.state.withLock { state in
        guard state.activeStreamID == streamID else { return }
        state.activeStreamID = nil
        subscription = state.activeStreamFinishedSubscription
        state.activeStreamFinishedSubscription = nil
      }
    }
    subscription?.cancel()
  }
}

// MARK: - Model Actor

extension CactusTranscriptionSession {
  private actor ModelActor {
    private let model: CactusLanguageModel

    init(model: sending CactusLanguageModel) {
      self.model = model
    }

    func transcribe(
      request: CactusTranscription.Request,
      options: CactusLanguageModel.InferenceOptions,
      onToken: @escaping @Sendable (String, UInt32) -> Void
    ) throws -> CactusLanguageModel.Transcription {
      if let audioURL = request.content.audioURL {
        return try self.model.transcribe(
          audio: audioURL,
          prompt: request.prompt,
          options: options,
          onToken: onToken
        )
      }

      if let pcmBytes = request.content.pcmBytes {
        return try self.model.transcribe(
          buffer: pcmBytes,
          prompt: request.prompt,
          options: options,
          onToken: onToken
        )
      }

      return try self.model.transcribe(
        buffer: [],
        prompt: request.prompt,
        options: options,
        onToken: onToken
      )
    }

    func withModel<T: Sendable, E: Error>(
      _ operation: @Sendable (CactusLanguageModel) throws(E) -> sending T
    ) throws(E) -> sending T {
      try operation(self.model)
    }
  }
}

// MARK: - Error

/// An error thrown by ``CactusTranscriptionSession`` stream APIs.
public struct CactusTranscriptionStreamError: Error, Hashable, Sendable {
  /// A human-readable description of the failure.
  public let message: String

  private init(message: String) {
    self.message = message
  }

  /// A transcription is already active for this session.
  public static let alreadyTranscribing = CactusTranscriptionStreamError(
    message: "A transcription is already in progress."
  )
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusTranscriptionSession: _Observable {}
