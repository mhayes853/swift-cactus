public final actor InMemoryTranscriptStore: CactusTranscriptStore {
  public static let shared = InMemoryTranscriptStore()

  private var transcripts = [CactusTranscript.Key: CactusTranscript]()

  public init() {}

  public func transcripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: CactusTranscript] {
    var values = [CactusTranscript.Key: CactusTranscript]()
    for key in keys {
      guard let transcript = self.transcripts[key] else { continue }
      values[key] = transcript
    }
    return values
  }

  public func save(transcripts: [CactusTranscript.Key: CactusTranscript]) async throws {
    self.transcripts.merge(transcripts, uniquingKeysWith: { _, new in new })
  }

  public func removeTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool] {
    var transcripts = [CactusTranscript.Key: Bool]()
    for key in keys {
      transcripts[key] = self.transcripts.removeValue(forKey: key) != nil
    }
    return transcripts
  }
}
