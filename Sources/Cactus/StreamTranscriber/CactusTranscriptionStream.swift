import CXXCactusShims
import Foundation

// MARK: - CactusTranscriptionStream

/// A thread-safe wrapper around ``CactusStreamTranscriber`` that exposes an async sequence
/// of processed transcriptions.
///
/// ```swift
/// import AVFoundation
///
/// let modelURL = try await CactusModelsDirectory.shared
///   .audioModelURL(for: "whisper-small")
/// let stream = try CactusTranscriptionStream(modelURL: modelURL)
///
/// let task = Task {
///   for try await chunk in stream {
///     print(chunk.confirmed, chunk.pending)
///   }
/// }
///
/// let buffer = try AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
/// try await stream.insert(buffer: buffer)
/// let finalized = try await stream.finish()
/// print(finalized.confirmed)
///
/// _ = await task.value
/// ```
public final class CactusTranscriptionStream: Sendable {
  public typealias Element = CactusStreamTranscriber.ProcessedTranscription

  private typealias Handler = @Sendable (Element) -> Void
  private typealias ErrorHandler = @Sendable (any Error) -> Void
  private typealias Finisher = @Sendable (CactusStreamTranscriber.FinalizedTranscription) -> Void

  private struct State {
    var handlers: [UUID: Handler]
    var errorHandlers: [UUID: ErrorHandler]
    var finishers: [UUID: Finisher]
  }

  private let transcriber: TranscriberActor
  private let state = RecursiveLock(State(handlers: [:], errorHandlers: [:], finishers: [:]))

  /// Creates a transcription stream from an existing transcriber.
  ///
  /// - Parameter transcriber: The transcriber to wrap.
  public init(transcriber: sending CactusStreamTranscriber) {
    self.transcriber = TranscriberActor(transcriber: transcriber)
  }

  /// Creates a transcription stream from a raw stream transcriber pointer.
  ///
  /// - Parameters:
  ///   - streamTranscribe: The raw stream transcriber pointer.
  ///   - isStreamPointerManaged: Whether the pointer is managed by the instance.
  public convenience init(
    streamTranscribe: sending cactus_stream_transcribe_t,
    isStreamPointerManaged: Bool = false
  ) {
    let transcriber = CactusStreamTranscriber(
      streamTranscribe: streamTranscribe,
      isStreamPointerManaged: isStreamPointerManaged
    )
    self.init(transcriber: transcriber)
  }

  /// Creates a transcription stream from a model URL.
  ///
  /// - Parameter modelURL: The URL of the model.
  public convenience init(modelURL: URL) throws {
    let transcriber = try CactusStreamTranscriber(modelURL: modelURL)
    self.init(transcriber: transcriber)
  }

  /// Creates a transcription stream from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  ///   - isModelPointerManaged: Whether the pointer is managed by the instance.
  public convenience init(
    model: sending cactus_model_t,
    isModelPointerManaged: Bool = false
  ) throws {
    let transcriber = try CactusStreamTranscriber(
      model: model,
      isModelPointerManaged: isModelPointerManaged
    )
    self.init(transcriber: transcriber)
  }
}

// MARK: - Async Sequence

extension CactusTranscriptionStream: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    fileprivate var iterator: AsyncThrowingStream<Element, any Error>.AsyncIterator

    public mutating func next() async throws -> Element? {
      try await self.iterator.next()
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream()
    let subscription = self.subscribe(
      { continuation.yield($0) },
      onError: { continuation.finish(throwing: $0) },
      onFinish: { _ in continuation.finish() }
    )
    continuation.onTermination = { _ in subscription.cancel() }
    return AsyncIterator(iterator: stream.makeAsyncIterator())
  }
}

// MARK: - Process

extension CactusTranscriptionStream {
  /// Processes a PCM audio buffer and returns interim transcription result.
  @discardableResult
  public func process(buffer: [UInt8]) async throws -> Element {
    do {
      let transcription = try await self.transcriber.insertAndProcess(buffer: buffer)
      self.state.withLock { state in
        for handler in state.handlers.values {
          handler(transcription)
        }
      }
      return transcription
    } catch {
      self.state.withLock { state in
        for handler in state.errorHandlers.values {
          handler(error)
        }
      }
      throw error
    }
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  @discardableResult
  public func process(buffer: UnsafeBufferPointer<UInt8>) async throws -> Element {
    try await self.process(buffer: Array(buffer))
  }
}

// MARK: - Finish

extension CactusTranscriptionStream {
  /// Finalizes the transcription stream.
  public func finish() async throws -> CactusStreamTranscriber.FinalizedTranscription {
    do {
      let finalized = try await self.transcriber.finalize()
      self.state.withLock { state in
        for finisher in state.finishers.values {
          finisher(finalized)
        }
        state.finishers.removeAll()
        state.handlers.removeAll()
        state.errorHandlers.removeAll()
      }
      return finalized
    } catch {
      self.state.withLock { state in
        for handler in state.errorHandlers.values {
          handler(error)
        }
      }
      throw error
    }
  }
}

// MARK: - Subscription

extension CactusTranscriptionStream {
  /// Subscribes to processed transcriptions.
  ///
  /// - Parameter handler: The handler invoked when transcriptions are emitted.
  /// - Returns: A ``CactusSubscription``.
  public func subscribe(
    _ handler: @escaping @Sendable (Element) -> Void,
    onError: @escaping @Sendable (any Error) -> Void = { _ in },
    onFinish: @escaping @Sendable (CactusStreamTranscriber.FinalizedTranscription) -> Void = { _ in
    }
  ) -> CactusSubscription {
    let id = UUID()
    self.state.withLock { state in
      state.handlers[id] = handler
      state.errorHandlers[id] = onError
      state.finishers[id] = onFinish
    }
    return CactusSubscription {
      self.state.withLock { state in
        state.handlers.removeValue(forKey: id)
        state.errorHandlers.removeValue(forKey: id)
        state.finishers.removeValue(forKey: id)
      }
    }
  }
}

// MARK: - TranscriberActor

extension CactusTranscriptionStream {
  private actor TranscriberActor {
    private let transcriber: CactusStreamTranscriber

    init(transcriber: CactusStreamTranscriber) {
      self.transcriber = transcriber
    }

    func insertAndProcess(buffer: [UInt8]) throws -> Element {
      try self.transcriber.process(buffer: buffer)
    }

    func finalize() throws -> CactusStreamTranscriber.FinalizedTranscription {
      try self.transcriber.stop()
    }
  }
}
