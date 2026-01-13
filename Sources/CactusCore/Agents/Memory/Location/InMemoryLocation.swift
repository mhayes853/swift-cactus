extension CactusMemoryLocation {
  public static func inMemory<Value>(_ key: String) -> Self where Self == InMemoryLocation<Value> {
    InMemoryLocation(key: Key(key: key))
  }
}

public struct InMemoryLocation<Value>: CactusMemoryLocation {
  let key: Key

  public struct Key: Hashable, Sendable {
    let key: String
  }

  public func key(in environment: CactusEnvironmentValues) -> Key {
    self.key
  }

  public func value(
    in environment: CactusEnvironmentValues,
    currentValue: Value
  ) async throws -> Value {
    currentValue
  }

  public func save(value: Value, in environment: CactusEnvironmentValues) async throws {
  }
}
