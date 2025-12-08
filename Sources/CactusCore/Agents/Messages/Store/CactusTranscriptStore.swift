public protocol CactusTranscriptStore {
  func hasTranscript(forKey key: CactusTranscriptKey) async throws -> Bool

  func transcripts(
    forKey keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: CactusTranscript]

  func save(transcripts: [CactusTranscriptKey: CactusTranscript]) async throws

  func removeTranscripts(forKey keys: Set<CactusTranscriptKey>) async throws
}

extension CactusTranscriptStore {
  public func hasTranscript(forKey key: CactusTranscriptKey) async throws -> Bool {
    try await self.transcript(forKey: key) != nil
  }

  public func transcript(forKey key: CactusTranscriptKey) async throws -> CactusTranscript? {
    try await self.transcripts(forKey: [key])[key]
  }

  public func save(transcript: CactusTranscript, forKey key: CactusTranscriptKey) async throws {
    try await self.save(transcripts: [key: transcript])
  }

  public func removeTranscript(forKey key: CactusTranscriptKey) async throws {
    try await self.removeTranscripts(forKey: [key])
  }
}
