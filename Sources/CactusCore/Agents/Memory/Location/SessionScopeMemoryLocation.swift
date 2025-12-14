import Foundation

extension CactusMemoryLocation {
  public var scopedToSession: _SessionScopeMemoryLocation<Self> {
    _SessionScopeMemoryLocation(base: self)
  }
}

public struct _SessionScopeMemoryLocation<Base: CactusMemoryLocation>: CactusMemoryLocation {
  public struct Key: Hashable, Sendable {
    let sessionId: UUID
    let base: Base.Key
  }

  let base: Base

  public func key(in environment: CactusEnvironmentValues) -> Key {
    guard let sessionId = environment.sessionId else {
      fatalError(
        """
        A session scoped key was declared in an agent that was invoked outside a \
        CactusAgenticSession. Ensure that the agent request has the 'sessionId' property set \
        accordingly in its environment.
        """
      )
    }
    return Key(sessionId: sessionId, base: self.base.key(in: environment))
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
