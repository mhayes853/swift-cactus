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
  private var isFinalized = false

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
    if self.isStreamPointerManaged, !self.isFinalized {
      _ = cactus_stream_transcribe_stop(self.streamTranscribe, nil, 0)
    }
    if let model {
      cactus_destroy(model)
    }
  }
}

// MARK: - Process

extension CactusStreamTranscriber {
  /// A result of processing audio in this transcriber.
  public struct ProcessedTranscription: Hashable, Sendable {
    /// Whether this transcription was handed off to cloud inference.
    public let didHandoffToCloud: Bool

    /// The portion of the transcription that has been confirmed.
    public let confirmed: String

    /// The portion of the transcription that is still pending confirmation.
    public let pending: String

    /// A list of ``CactusLanguageModel/FunctionCall`` instances from the model.
    public let functionCalls: [CactusLanguageModel.FunctionCall]

    /// The model's confidence in its transcription.
    public let confidence: Double

    /// The amount of time in milliseconds to generate the first token.
    private let timeToFirstTokenMs: Double

    /// The total generation time in milliseconds.
    private let totalTimeMs: Double

    /// The prefill tokens per second.
    public let prefillTps: Double

    /// The decode tokens per second.
    public let decodeTps: Double

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// The amount of time in seconds to generate the first token.
    public var timeIntervalToFirstToken: TimeInterval {
      self.timeToFirstTokenMs / 1000
    }

    /// The total generation time in seconds.
    public var totalTimeInterval: TimeInterval {
      self.totalTimeMs / 1000
    }
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``ProcessedTranscription``.
  public func process(buffer: [UInt8]) throws -> ProcessedTranscription {
    try self.ensureNotFinalized()
    return try buffer.withUnsafeBufferPointer { rawBuffer in
      try self.process(buffer: rawBuffer)
    }
  }

  /// Processes a PCM audio buffer and returns interim transcription result.
  ///
  /// - Parameter buffer: The PCM audio buffer to process.
  /// - Returns: A ``ProcessedTranscription``.
  public func process(buffer: UnsafeBufferPointer<UInt8>) throws -> ProcessedTranscription {
    try self.ensureNotFinalized()
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

extension CactusStreamTranscriber.ProcessedTranscription: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.didHandoffToCloud = try container.decode(Bool.self, forKey: .didHandoffToCloud)
    self.confirmed = try container.decode(String.self, forKey: .confirmed)
    self.pending = try container.decode(String.self, forKey: .pending)
    self.functionCalls = try container.decode(
      [CactusLanguageModel.FunctionCall].self,
      forKey: .functionCalls
    )
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
    self.prefillTps = try container.decode(Double.self, forKey: .prefillTps)
    self.decodeTps = try container.decode(Double.self, forKey: .decodeTps)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
  }
}

extension CactusStreamTranscriber.ProcessedTranscription: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.didHandoffToCloud, forKey: .didHandoffToCloud)
    try container.encode(self.confirmed, forKey: .confirmed)
    try container.encode(self.pending, forKey: .pending)
    try container.encode(self.functionCalls, forKey: .functionCalls)
    try container.encode(self.confidence, forKey: .confidence)
    try container.encode(self.timeToFirstTokenMs, forKey: .timeToFirstTokenMs)
    try container.encode(self.totalTimeMs, forKey: .totalTimeMs)
    try container.encode(self.prefillTps, forKey: .prefillTps)
    try container.encode(self.decodeTps, forKey: .decodeTps)
    try container.encode(self.ramUsageMb, forKey: .ramUsageMb)
    try container.encode(self.prefillTokens, forKey: .prefillTokens)
    try container.encode(self.decodeTokens, forKey: .decodeTokens)
    try container.encode(self.totalTokens, forKey: .totalTokens)
  }

  private enum CodingKeys: String, CodingKey {
    case didHandoffToCloud = "cloud_handoff"
    case confirmed
    case pending
    case functionCalls = "function_calls"
    case confidence
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
    case prefillTps = "prefill_tps"
    case decodeTps = "decode_tps"
    case ramUsageMb = "ram_usage_mb"
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
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
    try self.ensureNotFinalized()

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

    let finalized = try ffiDecoder.decode(FinalizedTranscription.self, from: responseData)
    self.isFinalized = true
    return finalized
  }
}

// MARK: - Helpers

extension CactusStreamTranscriber {
  private func ensureNotFinalized() throws {
    guard !self.isFinalized else {
      throw CactusStreamTranscriberError(message: "Stream transcriber is already finalized.")
    }
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
