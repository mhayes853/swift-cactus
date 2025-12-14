public protocol CactusMemoryLocation<Value>: Sendable {
  associatedtype Value: Sendable
  associatedtype Key: Hashable, Sendable

  func key(in environment: CactusEnvironmentValues) -> Key

  func value(in environment: CactusEnvironmentValues, currentValue: Value) async throws -> Value

  func save(value: Value, in environment: CactusEnvironmentValues) async throws
}
