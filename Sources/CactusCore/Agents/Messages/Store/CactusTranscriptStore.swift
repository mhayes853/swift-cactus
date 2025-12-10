// MARK: - CactusTranscriptStore

public protocol CactusTranscriptStore: Sendable {
  func hasTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool]

  func transcripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: CactusTranscript]

  func save(transcripts: [CactusTranscript.Key: CactusTranscript]) async throws

  @discardableResult
  func removeTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool]
}

extension CactusTranscriptStore {
  public func hasTranscript(forKey key: CactusTranscript.Key) async throws -> Bool {
    try await self.hasTranscripts(forKeys: [key])[key] == true
  }

  public func hasTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool] {
    let transcripts = try await self.transcripts(forKeys: keys)
    return [CactusTranscript.Key: Bool](
      uniqueKeysWithValues: keys.map { ($0, transcripts[$0] != nil) }
    )
  }

  public func transcript(forKey key: CactusTranscript.Key) async throws -> CactusTranscript? {
    try await self.transcripts(forKeys: [key])[key]
  }

  public func save(transcript: CactusTranscript, forKey key: CactusTranscript.Key) async throws {
    try await self.save(transcripts: [key: transcript])
  }

  @discardableResult
  public func removeTranscript(forKey key: CactusTranscript.Key) async throws -> Bool {
    try await self.removeTranscripts(forKeys: [key])[key] == true
  }
}

// MARK: - EnvironmentValue

extension CactusEnvironmentValues {
  public var transcriptStore: any CactusTranscriptStore {
    get { self[TranscriptStoreKey.self] }
    set { self[TranscriptStoreKey.self] = newValue }
  }

  private enum TranscriptStoreKey: Key {
    static let defaultValue: any CactusTranscriptStore = InMemoryTranscriptStore.shared
  }
}

extension CactusAgent {
  public func transcriptStore(
    _ store: any CactusTranscriptStore
  ) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.transcriptStore, store)
  }
}
