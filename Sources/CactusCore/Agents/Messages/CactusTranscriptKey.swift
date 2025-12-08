// MARK: - CactusAgentModelKey

public struct CactusTranscriptKey: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ value: some CustomStringConvertible) {
    self.rawValue = value.description
  }
}

// MARK: - Conformances

extension CactusTranscriptKey: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
}

extension CactusTranscriptKey: CustomDebugStringConvertible {
  public var debugDescription: String {
    "CactusTranscriptKey(\"\(self.rawValue)\")"
  }
}

extension CactusTranscriptKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}
