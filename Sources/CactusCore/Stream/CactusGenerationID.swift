import Foundation

// MARK: - CactusGenerationID

/// A unique identifier for a streamed model message.
public struct CactusGenerationID: Hashable, Sendable, RawRepresentable {
  /// The underlying UUID value.
  public let rawValue: UUID

  /// Creates an identifier from an existing UUID.
  ///
  /// - Parameter rawValue: The UUID backing this identifier.
  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }

  /// Creates a new random identifier.
  public init() {
    self.rawValue = UUID()
  }
}

// MARK: - Codable

extension CactusGenerationID: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.rawValue)
  }
}

extension CactusGenerationID: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(UUID.self))
  }
}
