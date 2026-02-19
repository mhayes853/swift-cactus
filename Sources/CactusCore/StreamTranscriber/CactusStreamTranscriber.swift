import CXXCactusShims
import Foundation

// MARK: - CactusStreamTranscriber

/// A low-level class for streaming audio transcriptions in real time.
///
/// This class provides a low-level interface for streaming audio transcriptions in real time, but
/// is not thread-safe or conforms to `Sendable`. Use ``CactusTranscriptionStream`` for a
/// higher-level thread-safe alternative.
public final class CactusStreamTranscriber {
  private let isStreamPointerManaged: Bool
  private static let responseBufferSize = 8192

  /// The underlying stream transcriber pointer.
  public let streamTranscribe: cactus_stream_transcribe_t

  private let model: cactus_model_t?

  /// Creates a stream transcriber from a raw pointer.
  ///
  /// - Parameters:
  ///   - streamTranscribe: The raw stream transcriber pointer.
  ///   - isStreamPointerManaged: Whether or not the stream transcriber pointer is managed by the instance.
  public convenience init(
    streamTranscribe: cactus_stream_transcribe_t,
    isStreamPointerManaged: Bool = false
  ) {
    self.init(
      streamTranscribe: streamTranscribe,
      model: nil,
      isStreamPointerManaged: isStreamPointerManaged
    )
  }

  /// Creates a stream transcriber from a model URL.
  ///
  /// - Parameters:
  ///   - modelURL: The URL of the model.
  public convenience init(modelURL: URL) throws {
    guard let model = cactus_init(modelURL.nativePath, nil, false) else {
      throw CactusStreamTranscriberError()
    }
    try self.init(model: model, isModelPointerManaged: true)
  }

  /// Creates a stream transcriber from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  ///   - isModelPointerManaged: Whether or not the model pointer is managed by the instance.
  public convenience init(model: cactus_model_t, isModelPointerManaged: Bool = false) throws {
    guard let streamTranscribe = cactus_stream_transcribe_start(model, nil) else {
      throw CactusStreamTranscriberError()
    }
    self.init(
      streamTranscribe: streamTranscribe,
      model: isModelPointerManaged ? model : nil,
      isStreamPointerManaged: true
    )
  }

  private init(
    streamTranscribe: cactus_stream_transcribe_t,
    model: cactus_model_t?,
    isStreamPointerManaged: Bool = false
  ) {
    self.streamTranscribe = streamTranscribe
    self.model = model
    self.isStreamPointerManaged = isStreamPointerManaged
  }

  deinit {
    if self.isStreamPointerManaged {
      let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Self.responseBufferSize)
      defer { responseBuffer.deallocate() }
      _ = cactus_stream_transcribe_stop(self.streamTranscribe, responseBuffer, Self.responseBufferSize)
    }
    if let model {
      cactus_destroy(model)
    }
  }
}

// MARK: - Process

extension CactusStreamTranscriber {
  /// A result of processing audio in this transcriber.
  public struct ProcessedTranscription: Codable, Hashable, Sendable {
    /// The portion of the transcription that has been confirmed.
    public let confirmed: String
    /// The portion of the transcription that is still pending confirmation.
    public let pending: String
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``ProcessedTranscription``.
  public func process(buffer: [UInt8]) throws -> ProcessedTranscription {
    try buffer.withUnsafeBufferPointer { rawBuffer in
      try self.process(buffer: rawBuffer)
    }
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``ProcessedTranscription``.
  public func process(buffer: UnsafeBufferPointer<UInt8>) throws -> ProcessedTranscription {
    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Self.responseBufferSize)
    defer { responseBuffer.deallocate() }

    let result = cactus_stream_transcribe_process(
      self.streamTranscribe,
      buffer.baseAddress,
      buffer.count,
      responseBuffer,
      Self.responseBufferSize * MemoryLayout<CChar>.stride
    )

    var responseData = Data()
    for i in 0..<strnlen(responseBuffer, Self.responseBufferSize) {
      responseData.append(UInt8(bitPattern: responseBuffer[i]))
    }

    guard result != -1 else {
      let response = try ffiDecoder.decode(FFIErrorResponse.self, from: responseData)
      throw CactusStreamTranscriberError(message: response.error)
    }

    return try ffiDecoder.decode(ProcessedTranscription.self, from: responseData)
  }
}

// MARK: - Stop

extension CactusStreamTranscriber {
  /// A finalized transcription of the audio.
  public struct FinalizedTranscription: Codable, Hashable, Sendable {
    /// The fully confirmed transcription.
    public let confirmed: String
  }

  /// Stops streaming transcription and returns the finalized result.
  ///
  /// - Returns: A ``FinalizedTranscription``.
  public func stop() throws -> FinalizedTranscription {
    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Self.responseBufferSize)
    defer { responseBuffer.deallocate() }

    let result = cactus_stream_transcribe_stop(
      self.streamTranscribe,
      responseBuffer,
      Self.responseBufferSize * MemoryLayout<CChar>.stride
    )

    var responseData = Data()
    for i in 0..<strnlen(responseBuffer, Self.responseBufferSize) {
      responseData.append(UInt8(bitPattern: responseBuffer[i]))
    }

    guard result != -1 else {
      let response = try ffiDecoder.decode(FFIErrorResponse.self, from: responseData)
      throw CactusStreamTranscriberError(message: response.error)
    }

    return try ffiDecoder.decode(FinalizedTranscription.self, from: responseData)
  }
}

// MARK: - CactusStreamTranscriberError

/// An error thrown by ``CactusStreamTranscriber``.
public struct CactusStreamTranscriberError: Error, Hashable {
  /// The error message from the underlying FFI, if available.
  public let message: String?

  fileprivate init(message: String? = nil) {
    self.message = message ?? cactus_get_last_error().map { String(cString: $0) }
  }
}
