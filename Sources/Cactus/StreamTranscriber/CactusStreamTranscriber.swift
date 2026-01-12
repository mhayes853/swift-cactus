import CXXCactusShims
import Foundation

// MARK: - CactusStreamTranscriber

/// A class for streaming audio transcriptions in real time.
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
  ///   - contextSize: The context size.
  public convenience init(modelURL: URL, contextSize: Int) throws {
    guard let model = cactus_init(modelURL.nativePath, contextSize, nil) else {
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
    guard let streamTranscribe = cactus_stream_transcribe_init(model) else {
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
      cactus_stream_transcribe_destroy(self.streamTranscribe)
    }
    if let model {
      cactus_destroy(model)
    }
  }
}

// MARK: - Insert

extension CactusStreamTranscriber {
  /// Inserts a PCM audio buffer into this transcriber.
  public func insert(buffer: [UInt8]) throws {
    try buffer.withUnsafeBufferPointer { try self.insert(buffer: $0) }
  }

  /// Inserts a PCM audio buffer into this transcriber.
  public func insert(buffer: UnsafeBufferPointer<UInt8>) throws {
    let result = cactus_stream_transcribe_insert(
      self.streamTranscribe,
      buffer.baseAddress,
      buffer.count
    )
    guard result == 0 else { throw CactusStreamTranscriberError() }
  }
}

// MARK: - Process

extension CactusStreamTranscriber {
  /// Options for processing the existing audio in this transcriber.
  public struct ProcessOptions: Codable, Sendable {
    /// The threshold used when confirming previously transcribed text.
    public var confirmationThreshold: Double

    /// Creates process options.
    ///
    /// - Parameter confirmationThreshold: The threshold used when confirming previously transcribed text.
    public init(confirmationThreshold: Double = 0.95) {
      self.confirmationThreshold = confirmationThreshold
    }

    private enum CodingKeys: String, CodingKey {
      case confirmationThreshold = "confirmation_threshold"
    }
  }

  /// A result of processing the existing audio in this transcriber.
  public struct ProcessedTranscription: Codable, Hashable, Sendable {
    /// The portion of the transcription that has been confirmed.
    public let confirmed: String
    /// The portion of the transcription that is still pending confirmation.
    public let pending: String
  }

  /// Processes the existing audio in this transcriber.
  ///
  /// - Parameter options: The ``ProcessOptions`` to use.
  /// - Returns: A ``ProcessedTranscription``.
  public func process(options: ProcessOptions = ProcessOptions()) throws -> ProcessedTranscription {
    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Self.responseBufferSize)
    defer { responseBuffer.deallocate() }

    let result = cactus_stream_transcribe_process(
      self.streamTranscribe,
      responseBuffer,
      Self.responseBufferSize * MemoryLayout<CChar>.stride,
      String(decoding: try ffiEncoder.encode(options), as: UTF8.self)
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

// MARK: - Finalize

extension CactusStreamTranscriber {
  /// A finalized transcription of the audio.
  public struct FinalizedTranscription: Codable, Hashable, Sendable {
    /// The fully confirmed transcription.
    public let confirmed: String
  }

  /// Returns a finalized transcription of the audio in this transcriber.
  public func finalize() throws -> FinalizedTranscription {
    let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Self.responseBufferSize)
    defer { responseBuffer.deallocate() }

    let result = cactus_stream_transcribe_finalize(
      self.streamTranscribe,
      responseBuffer,
      Self.responseBufferSize * MemoryLayout<CChar>.stride
    )

    var responseData = Data()
    for i in 0..<strnlen(responseBuffer, Self.responseBufferSize) {
      responseData.append(UInt8(bitPattern: responseBuffer[i]))
    }

    guard result != 0 else {
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
