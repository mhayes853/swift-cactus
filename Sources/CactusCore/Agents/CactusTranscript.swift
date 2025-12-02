// MARK: - CactusTranscript

public struct CactusTranscript: Hashable, Sendable, Codable {
}

// MARK: - Environment

extension CactusAgent {
  public func transcript(_ transcript: CactusTranscript) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.transcript, transcript)
  }
}

extension CactusEnvironmentValues {
  public var transcript: CactusTranscript {
    get { self[TranscriptKey.self] }
    set { self[TranscriptKey.self] = newValue }
  }

  private enum TranscriptKey: Key {
    static let defaultValue = CactusTranscript()
  }
}
