import Foundation

// MARK: - CactusGenerationID

public struct CactusMessageID: Hashable, Sendable, RawRepresentable {
  public let rawValue: UUID

  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init() {
    self.rawValue = UUID()
  }
}

// MARK: - Codable

extension CactusMessageID: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.rawValue)
  }
}

extension CactusMessageID: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(UUID.self))
  }
}
