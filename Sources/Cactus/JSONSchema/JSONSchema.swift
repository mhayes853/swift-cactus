// MARK: - JSONSchema

public indirect enum JSONSchema: Hashable, Sendable, Codable {
  case boolean(Bool)
  case object(Object)
}

// MARK: - Object

extension JSONSchema {
  public struct Object: Hashable, Sendable, Codable {

  }
}
