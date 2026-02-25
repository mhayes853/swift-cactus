import CXXCactusShims
import Foundation

// MARK: - CactusStreamTranscriberActor

/// An actor that isolates a ``CactusStreamTranscriber``.
///
/// This actor wraps a ``CactusStreamTranscriber`` to provide thread-safe and background access to
/// streaming audio transcription.
///
/// ```swift
/// let actor = try await CactusStreamTranscriberActor(modelURL: modelURL)
///
/// let result = try await actor.process(buffer: audioBuffer)
/// print(result.confirmed, result.pending)
///
/// let finalized = try await actor.stop()
/// print(finalized.confirmed)
/// ```
public actor CactusStreamTranscriberActor {
  /// The underlying stream transcriber.
  public var streamTranscriber: CactusStreamTranscriber

  /// The custom `SerialExecutor` used by this actor, if provided.
  public let executor: (any SerialExecutor)?

  private let defaultExecutor: DefaultActorExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    if let executor {
      return executor.asUnownedSerialExecutor()
    }
    return self.defaultExecutor.unownedExecutor
  }

  /// Creates an actor from an existing stream transcriber.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - streamTranscriber: The underlying stream transcriber.
  public init(
    executor: (any SerialExecutor)? = nil,
    streamTranscriber: consuming sending CactusStreamTranscriber
  ) {
    self.executor = executor
    self.streamTranscriber = consume streamTranscriber
    self.defaultExecutor = DefaultActorExecutor()
  }

  /// Creates a stream transcriber from a model URL.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - modelURL: The URL of the model.
  public init(executor: (any SerialExecutor)? = nil, modelURL: URL) throws {
    let streamTranscriber = try CactusStreamTranscriber(modelURL: modelURL)
    self.init(executor: executor, streamTranscriber: consume streamTranscriber)
  }

  /// Creates a stream transcriber from a raw model pointer.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - model: The raw model pointer.
  public init(
    executor: (any SerialExecutor)? = nil,
    model: consuming sending cactus_model_t
  ) throws {
    let streamTranscriber = try CactusStreamTranscriber(model: model)
    self.init(executor: executor, streamTranscriber: consume streamTranscriber)
  }

  /// Creates a stream transcriber from a raw stream transcriber pointer.
  ///
  /// The memory for the stream transcriber pointer is managed by the instance.
  ///
  /// - Parameters:
  ///   - executor: A custom `SerialExecutor` to use for this actor.
  ///   - streamTranscribe: The raw stream transcriber pointer.
  public init(
    executor: (any SerialExecutor)? = nil,
    streamTranscribe: consuming sending cactus_stream_transcribe_t
  ) {
    self.executor = executor
    self.streamTranscriber = CactusStreamTranscriber(
      streamTranscribe: streamTranscribe
    )
    self.defaultExecutor = DefaultActorExecutor()
  }
}

// MARK: - Process

extension CactusStreamTranscriberActor {
  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``CactusStreamTranscriber/ProcessedTranscription``.
  public func process(buffer: [UInt8]) async throws
    -> CactusStreamTranscriber.ProcessedTranscription
  {
    try self.streamTranscriber.process(buffer: buffer)
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``CactusStreamTranscriber/ProcessedTranscription``.
  public func process(buffer: UnsafeBufferPointer<UInt8>) async throws
    -> CactusStreamTranscriber.ProcessedTranscription
  {
    try self.streamTranscriber.process(buffer: buffer)
  }
}

// MARK: - Stop

extension CactusStreamTranscriberActor {
  /// Stops streaming transcription and returns the finalized result.
  ///
  /// - Returns: A ``CactusStreamTranscriber/FinalizedTranscription``.
  public func stop() async throws -> CactusStreamTranscriber.FinalizedTranscription {
    try self.streamTranscriber.mutatingStop()
  }
}

// MARK: - Exclusive Access

extension CactusStreamTranscriberActor {
  /// Provides exclusive access to the underlying stream transcriber.
  ///
  /// This method allows direct synchronous and exclusive access to the ``CactusStreamTranscriber``.
  ///
  /// ```swift
  /// let result = try await actor.withStreamTranscriber { transcriber in
  ///   // ...
  /// }
  /// ```
  ///
  /// - Parameter operation: An operation to run with the transcriber.
  /// - Returns: The operation return value.
  public func withStreamTranscriber<T: ~Copyable, E: Error>(
    _ operation: (borrowing CactusStreamTranscriber) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try operation(self.streamTranscriber)
  }

  /// Provides scoped access to the underlying stream transcriber pointer.
  ///
  /// - Parameter operation: An operation to run with the stream transcriber pointer.
  /// - Returns: The operation return value.
  public func withStreamTranscribePointer<T: ~Copyable, E: Error>(
    _ operation: (cactus_stream_transcribe_t) throws(E) -> sending T
  ) async throws(E) -> sending T {
    try self.streamTranscriber.withStreamTranscribePointer(operation)
  }
}
