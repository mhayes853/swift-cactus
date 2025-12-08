public final actor InMemoryTranscriptStore: CactusTranscriptStore {
  public static let shared = InMemoryTranscriptStore()

  private var transcripts = [CactusTranscriptKey: CactusTranscript]()

  public init() {}

  public func transcripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: CactusTranscript] {
    var values = [CactusTranscriptKey: CactusTranscript]()
    for key in keys {
      guard let transcript = self.transcripts[key] else { continue }
      values[key] = transcript
    }
    return values
  }

  public func save(transcripts: [CactusTranscriptKey: CactusTranscript]) async throws {
    self.transcripts.merge(transcripts, uniquingKeysWith: { _, new in new })
  }

  public func removeTranscripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: Bool] {
    var transcripts = [CactusTranscriptKey: Bool]()
    for key in keys {
      transcripts[key] = self.transcripts.removeValue(forKey: key) != nil
    }
    return transcripts
  }
}
