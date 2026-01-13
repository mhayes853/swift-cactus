import Foundation

extension CactusMemoryLocation {
  public func scope(_ scope: CactusMemoryScope) -> _ScopedMemoryLocation<Self> {
    _ScopedMemoryLocation(base: self, scope: scope)
  }
}

public struct _ScopedMemoryLocation<Base: CactusMemoryLocation>: CactusMemoryLocation {
  public struct Key: Hashable, Sendable {
    let scope: CactusMemoryScope
    let base: Base.Key
  }

  let base: Base
  let scope: CactusMemoryScope

  public func memory(in environment: CactusEnvironmentValues) -> CactusMemoryStore {
    self.scope.memory(in: environment)
  }

  public func key(in environment: CactusEnvironmentValues) -> Key {
    Key(scope: scope, base: base.key(in: environment))
  }

  public func value(
    in environment: CactusEnvironmentValues,
    currentValue: Base.Value
  ) async throws -> Base.Value {
    try await self.base.value(in: environment, currentValue: currentValue)
  }

  public func save(value: Value, in environment: CactusEnvironmentValues) async throws {
    try await self.base.save(value: value, in: environment)
  }
}
