public protocol CactusMemoryLocation<Value>: Sendable {
  associatedtype Value: Sendable
  associatedtype Key: Hashable, Sendable

  func memory(in environment: CactusEnvironmentValues) -> CactusMemoryStore

  func key(in environment: CactusEnvironmentValues) -> Key

  func value(in environment: CactusEnvironmentValues, currentValue: Value) async throws -> Value

  func save(value: Value, in environment: CactusEnvironmentValues) async throws
}

extension CactusMemoryLocation {
  public func memory(in environment: CactusEnvironmentValues) -> CactusMemoryStore {
    environment.defaultMemoryScope.memory(in: environment)
  }
}
