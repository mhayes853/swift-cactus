public protocol CactusTranscriptStore {
  func hasTranscripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: Bool]

  func transcripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: CactusTranscript]

  func save(transcripts: [CactusTranscriptKey: CactusTranscript]) async throws

  @discardableResult
  func removeTranscripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: Bool]
}

extension CactusTranscriptStore {
  public func hasTranscript(forKey key: CactusTranscriptKey) async throws -> Bool {
    try await self.hasTranscripts(forKeys: [key])[key] == true
  }

  public func hasTranscripts(
    forKeys keys: Set<CactusTranscriptKey>
  ) async throws -> [CactusTranscriptKey: Bool] {
    let transcripts = try await self.transcripts(forKeys: keys)
    return [CactusTranscriptKey: Bool](
      uniqueKeysWithValues: keys.map { ($0, transcripts[$0] != nil) }
    )
  }

  public func transcript(forKey key: CactusTranscriptKey) async throws -> CactusTranscript? {
    try await self.transcripts(forKeys: [key])[key]
  }

  public func save(transcript: CactusTranscript, forKey key: CactusTranscriptKey) async throws {
    try await self.save(transcripts: [key: transcript])
  }

  @discardableResult
  public func removeTranscript(forKey key: CactusTranscriptKey) async throws -> Bool {
    try await self.removeTranscripts(forKeys: [key])[key] == true
  }
}
