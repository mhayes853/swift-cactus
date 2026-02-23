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
///   .modelURL(for: .whisperSmall())
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

  private let streamTranscriberActor: CactusStreamTranscriberActor
  private let state = RecursiveLock(State(handlers: [:], errorHandlers: [:], finishers: [:]))

  /// Creates a transcription stream from an existing streamTranscriberActor.
  ///
  /// - Parameter streamTranscriberActor: The streamTranscriberActor to wrap.
  public init(
    executor: (any SerialExecutor)? = nil,
    streamTranscriber: sending CactusStreamTranscriber
  ) {
    self.streamTranscriberActor = CactusStreamTranscriberActor(
      executor: executor,
      streamTranscriber: streamTranscriber
    )
  }

  /// Creates a transcription stream from an existing streamTranscriberActor actor.
  ///
  /// - Parameter streamTranscriberActor: The streamTranscriberActor actor to wrap.
  public init(streamTranscriberActor: CactusStreamTranscriberActor) {
    self.streamTranscriberActor = streamTranscriberActor
  }

  /// Creates a transcription stream from a raw stream streamTranscriberActor pointer.
  ///
  /// - Parameter streamTranscribe: The raw stream streamTranscriberActor pointer.
  public init(streamTranscribe: sending cactus_stream_transcribe_t) {
    let streamTranscriberActor = CactusStreamTranscriber(
      streamTranscribe: streamTranscribe,
      isStreamPointerManaged: true
    )
    self.streamTranscriberActor = CactusStreamTranscriberActor(streamTranscriber: streamTranscriberActor)
  }

  /// Creates a transcription stream from a model URL.
  ///
  /// - Parameter modelURL: The URL of the model.
  public init(modelURL: URL) throws {
    let streamTranscriberActor = try CactusStreamTranscriber(modelURL: modelURL)
    self.streamTranscriberActor = CactusStreamTranscriberActor(streamTranscriber: streamTranscriberActor)
  }

  /// Creates a transcription stream from a raw model pointer.
  ///
  /// - Parameter model: The raw model pointer.
  public init(model: sending cactus_model_t) throws {
    let streamTranscriberActor = try CactusStreamTranscriber(
      model: model,
      isModelPointerManaged: true
    )
    self.streamTranscriberActor = CactusStreamTranscriberActor(streamTranscriber: streamTranscriberActor)
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
      let transcription = try await self.streamTranscriberActor.process(buffer: buffer)
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
      let finalized = try await self.streamTranscriberActor.stop()
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
    onFinish: @escaping @Sendable (CactusStreamTranscriber.FinalizedTranscription) -> Void = { _ in }
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
