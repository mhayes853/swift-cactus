// MARK: - Key

extension CactusTranscript {
  public struct Key: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    public init(_ value: some CustomStringConvertible) {
      self.rawValue = value.description
    }
  }
}

// MARK: - Conformances

extension CactusTranscript.Key: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
}

extension CactusTranscript.Key: CustomDebugStringConvertible {
  public var debugDescription: String {
    "CactusTranscript.Key(\"\(self.rawValue)\")"
  }
}

extension CactusTranscript.Key: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}
