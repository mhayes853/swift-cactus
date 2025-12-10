import Foundation

public final actor FilesystemTranscriptStore: CactusTranscriptStore {
  public nonisolated let directoryBaseURL: URL
  private let manager: FileManager
  private let encoder: any TopLevelEncoder<Data>
  private let decoder: any TopLevelDecoder<Data>

  private var directoryExists: Bool {
    self.manager.fileExists(atPath: self.directoryBaseURL.relativePath)
  }

  public init(
    directoryBaseURL: URL,
    encoder: sending any TopLevelEncoder<Data> = JSONEncoder(),
    decoder: sending any TopLevelDecoder<Data> = JSONDecoder()
  ) {
    self.directoryBaseURL = directoryBaseURL
    self.manager = .default
    self.encoder = encoder
    self.decoder = decoder
  }

  public func transcripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: CactusTranscript] {
    guard self.directoryExists else { return [:] }
    var transcripts = [CactusTranscript.Key: CactusTranscript]()
    for key in keys {
      let url = self.directoryBaseURL.appendingPathComponent(key.description)
      guard self.manager.fileExists(atPath: url.relativePath) else { continue }
      transcripts[key] = try self.decoder.decode(CactusTranscript.self, from: Data(contentsOf: url))
    }
    return transcripts
  }

  public func hasTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool] {
    guard self.directoryExists else {
      return [CactusTranscript.Key: Bool](uniqueKeysWithValues: keys.map { ($0, false) })
    }
    var results = [CactusTranscript.Key: Bool]()
    for key in keys {
      let url = self.directoryBaseURL.appendingPathComponent(key.description)
      results[key] = self.manager.fileExists(atPath: url.relativePath)
    }
    return results
  }

  public func save(transcripts: [CactusTranscript.Key: CactusTranscript]) async throws {
    try self.ensureDirectory()
    for (key, transcript) in transcripts {
      let url = self.directoryBaseURL.appendingPathComponent(key.description)
      try self.encoder.encode(transcript).write(to: url)
    }
  }

  public func removeTranscripts(
    forKeys keys: Set<CactusTranscript.Key>
  ) async throws -> [CactusTranscript.Key: Bool] {
    guard self.directoryExists else {
      return [CactusTranscript.Key: Bool](uniqueKeysWithValues: keys.map { ($0, false) })
    }
    var results = [CactusTranscript.Key: Bool]()
    for key in keys {
      let url = self.directoryBaseURL.appendingPathComponent(key.description)
      let fileExists = self.manager.fileExists(atPath: url.relativePath)
      results[key] = fileExists
      guard fileExists else { continue }
      try self.manager.removeItem(at: url)
    }
    return results
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(
      at: self.directoryBaseURL,
      withIntermediateDirectories: true
    )
  }
}
