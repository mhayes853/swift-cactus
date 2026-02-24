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
  public convenience init(
    streamTranscribe: cactus_stream_transcribe_t
  ) {
    self.init(
      streamTranscribe: streamTranscribe,
      model: nil
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
    try self.init(model: model)
  }

  /// Creates a stream transcriber from a raw model pointer.
  ///
  /// - Parameters:
  ///   - model: The raw model pointer.
  public convenience init(model: cactus_model_t) throws {
    guard let streamTranscribe = cactus_stream_transcribe_start(model, nil) else {
      throw CactusStreamTranscriberError()
    }
    self.init(
      streamTranscribe: streamTranscribe,
      model: model
    )
  }

  private init(
    streamTranscribe: cactus_stream_transcribe_t,
    model: cactus_model_t?
  ) {
    self.streamTranscribe = streamTranscribe
    self.model = model
    self.isStreamPointerManaged = true
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

    /// The duration of the audio buffer that was processed.
    public let bufferDuration: CactusDuration

    /// The model's confidence in its transcription.
    public let confidence: Double

    /// The result from cloud transcription, if applicable.
    public let cloudResult: String?

    /// The cloud job ID for the transcription request.
    public let cloudJobId: Int

    /// The cloud job ID for the transcription result.
    public let cloudResultJobId: Int

    /// The amount of time to generate the first token.
    public let durationToFirstToken: CactusDuration

    /// The total generation time.
    public let totalDuration: CactusDuration

    /// The number of prefilled tokens.
    public let prefillTokens: Int

    /// The prefill tokens per second.
    public let prefillTps: Double

    /// The number of tokens decoded.
    public let decodeTokens: Int

    /// The decode tokens per second.
    public let decodeTps: Double

    /// The total amount of tokens that make up the response.
    public let totalTokens: Int

    /// The current process RAM usage in MB.
    public let ramUsageMb: Double
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
    self.bufferDuration = .milliseconds(try container.decode(Double.self, forKey: .bufferDurationMs))
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.cloudResult = try container.decodeIfPresent(String.self, forKey: .cloudResult)
    self.cloudJobId = try container.decode(Int.self, forKey: .cloudJobId)
    self.cloudResultJobId = try container.decode(Int.self, forKey: .cloudResultJobId)
    self.durationToFirstToken = .milliseconds(
      try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    )
    self.totalDuration = .milliseconds(
      try container.decode(Double.self, forKey: .totalTimeMs)
    )
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.prefillTps = try container.decode(Double.self, forKey: .prefillTps)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.decodeTps = try container.decode(Double.self, forKey: .decodeTps)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.ramUsageMb = try container.decode(Double.self, forKey: .ramUsageMb)
  }
}

extension CactusStreamTranscriber.ProcessedTranscription: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.didHandoffToCloud, forKey: .didHandoffToCloud)
    try container.encode(self.confirmed, forKey: .confirmed)
    try container.encode(self.pending, forKey: .pending)
    try container.encode(self.bufferDuration.secondsDouble * 1000, forKey: .bufferDurationMs)
    try container.encode(self.confidence, forKey: .confidence)
    try container.encodeIfPresent(self.cloudResult, forKey: .cloudResult)
    try container.encode(self.cloudJobId, forKey: .cloudJobId)
    try container.encode(self.cloudResultJobId, forKey: .cloudResultJobId)
    try container.encode(self.durationToFirstToken.secondsDouble * 1000, forKey: .timeToFirstTokenMs)
    try container.encode(self.totalDuration.secondsDouble * 1000, forKey: .totalTimeMs)
    try container.encode(self.prefillTokens, forKey: .prefillTokens)
    try container.encode(self.prefillTps, forKey: .prefillTps)
    try container.encode(self.decodeTokens, forKey: .decodeTokens)
    try container.encode(self.decodeTps, forKey: .decodeTps)
    try container.encode(self.totalTokens, forKey: .totalTokens)
    try container.encode(self.ramUsageMb, forKey: .ramUsageMb)
  }

  private enum CodingKeys: String, CodingKey {
    case didHandoffToCloud = "cloud_handoff"
    case confirmed
    case pending
    case bufferDurationMs = "buffer_duration_ms"
    case confidence
    case cloudResult = "cloud_result"
    case cloudJobId = "cloud_job_id"
    case cloudResultJobId = "cloud_result_job_id"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
    case prefillTokens = "prefill_tokens"
    case prefillTps = "prefill_tps"
    case decodeTokens = "decode_tokens"
    case decodeTps = "decode_tps"
    case totalTokens = "total_tokens"
    case ramUsageMb = "ram_usage_mb"
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
