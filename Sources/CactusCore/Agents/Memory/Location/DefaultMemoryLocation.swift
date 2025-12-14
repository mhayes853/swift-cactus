// MARK: - Loader

extension CactusMemoryLocation {
  public typealias Default = _DefaultValueMemoryLocation<Self>
}

public struct _DefaultValueMemoryLocation<Base: CactusMemoryLocation>: CactusMemoryLocation {
  public static func withDefault(
    _ loader: Base,
    _ value: @escaping @autoclosure @Sendable () -> Value
  ) -> Self {
    Self(base: loader, _defaultValue: value)
  }

  public var defaultValue: Base.Value {
    self._defaultValue()
  }

  let base: Base
  let _defaultValue: @Sendable () -> Base.Value

  public func key(in environment: CactusEnvironmentValues) -> Base.Key {
    self.base.key(in: environment)
  }

  public func value(
    in environment: CactusEnvironmentValues,
    currentValue: Base.Value
  ) async throws -> Base.Value {
    try await self.base.value(in: environment, currentValue: currentValue)
  }

  public func save(value: Base.Value, in environment: CactusEnvironmentValues) async throws {
    try await self.base.save(value: value, in: environment)
  }
}

// MARK: - Memory

extension Memory {
  public init(_ location: (some CactusMemoryLocation<Value>).Default) {
    self.init(wrappedValue: location.defaultValue, location)
  }
}
