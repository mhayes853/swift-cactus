public final actor InMemoryTranscriptStore: CactusTranscriptStore {
  private var transcripts = [CactusTranscriptKey: CactusTranscript]()

  public init() {}

  public func transcripts(
    forKey keys: Set<CactusTranscriptKey>
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

  public func removeTranscripts(forKey keys: Set<CactusTranscriptKey>) async throws {
    for key in keys {
      self.transcripts.removeValue(forKey: key)
    }
  }
}
