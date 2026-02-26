import Foundation
import StreamParsingCore

// MARK: - CactusCompletion

/// The result produced by one completion turn.
///
/// This value only contains entries appended during the turn that produced it.
/// It does not represent the session's full transcript.
public struct CactusCompletion<Output: Sendable>: Sendable {
  /// The parsed output for the completion turn.
  public let output: Output

  /// The entries appended during this completion turn.
  public let entries: [CactusCompletionEntry]

  /// Creates a completion value.
  public init(output: Output, entries: [CactusCompletionEntry]) {
    precondition(!entries.isEmpty, "Entries must not be empty.")
    self.output = output
    self.entries = entries
  }
}

extension CactusCompletion: Equatable where Output: Hashable {}
extension CactusCompletion: Hashable where Output: Hashable {}

extension CactusCompletion: StreamParseable where Output: StreamParseable {
  public typealias Partial = Output.Partial

  public var streamPartialValue: Partial {
    self.output.streamPartialValue
  }
}

// MARK: - Computed Values

extension CactusCompletion {
  /// The number of prefilled tokens in the final entry metrics.
  public var prefillTokens: Int {
    self.lastEntry.prefillTokens
  }

  /// The number of decoded tokens in the final entry metrics.
  public var decodeTokens: Int {
    self.lastEntry.decodeTokens
  }

  /// The total number of tokens in the final entry metrics.
  public var totalTokens: Int {
    self.lastEntry.totalTokens
  }

  /// The confidence for the final entry metrics.
  public var confidence: Double {
    self.lastEntry.confidence
  }

  /// Prefill throughput for the final entry metrics.
  public var prefillTps: Double {
    self.lastEntry.prefillTps
  }

  /// Decode throughput for the final entry metrics.
  public var decodeTps: Double {
    self.lastEntry.decodeTps
  }

  /// RAM usage for the final entry metrics.
  public var ramUsageMb: Double {
    self.lastEntry.ramUsageMb
  }

  /// Time to first token for the final entry metrics.
  public var durationToFirstToken: CactusDuration {
    self.lastEntry.durationToFirstToken
  }

  /// Total generation time for the final entry metrics.
  public var totalDuration: CactusDuration {
    self.lastEntry.totalDuration
  }

  private var lastEntry: CactusCompletionEntry {
    self.entries[self.entries.index(before: self.entries.endIndex)]
  }
}

// MARK: - CactusCompletionEntry

/// A completion entry that wraps a transcript entry and its metrics.
public struct CactusCompletionEntry: Hashable, Sendable, Identifiable {
  /// The transcript entry associated with this completion entry.
  public var transcriptEntry: CactusTranscript.Element

  /// The number of prefilled tokens.
  public var prefillTokens: Int

  /// The number of decoded tokens.
  public var decodeTokens: Int

  /// The total number of tokens.
  public var totalTokens: Int

  /// The model confidence for the entry.
  public var confidence: Double

  /// The prefill tokens-per-second throughput.
  public var prefillTps: Double

  /// The decode tokens-per-second throughput.
  public var decodeTps: Double

  /// The process RAM usage in MB.
  public var ramUsageMb: Double

  /// The time to first token.
  public var durationToFirstToken: CactusDuration

  /// The total generation duration.
  public var totalDuration: CactusDuration

  public var id: CactusGenerationID {
    self.transcriptEntry.id
  }

  /// Creates a completion entry.
  ///
  /// - Parameters:
  ///   - transcriptEntry: The transcript element associated with this completion entry.
  ///   - prefillTokens: The number of prefilled tokens.
  ///   - decodeTokens: The number of decoded tokens.
  ///   - totalTokens: The total number of generated tokens.
  ///   - confidence: The model confidence for the generated response.
  ///   - prefillTps: The prefill throughput in tokens per second.
  ///   - decodeTps: The decode throughput in tokens per second.
  ///   - ramUsageMb: The process memory usage in megabytes.
  ///   - durationToFirstToken: The time until the first token was produced.
  ///   - totalDuration: The total generation duration.
  public init(
    transcriptEntry: CactusTranscript.Element,
    prefillTokens: Int,
    decodeTokens: Int,
    totalTokens: Int,
    confidence: Double,
    prefillTps: Double,
    decodeTps: Double,
    ramUsageMb: Double,
    durationToFirstToken: CactusDuration,
    totalDuration: CactusDuration
  ) {
    self.transcriptEntry = transcriptEntry
    self.prefillTokens = prefillTokens
    self.decodeTokens = decodeTokens
    self.totalTokens = totalTokens
    self.confidence = confidence
    self.prefillTps = prefillTps
    self.decodeTps = decodeTps
    self.ramUsageMb = ramUsageMb
    self.durationToFirstToken = durationToFirstToken
    self.totalDuration = totalDuration
  }
}
