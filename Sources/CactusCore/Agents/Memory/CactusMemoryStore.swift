public final class CactusMemoryStore: Sendable {
  public static let shared = CactusMemoryStore()

  private let values = Lock([AnyHashableSendable: any Sendable]())

  public init() {}

  public func value<Value>(
    at location: some CactusMemoryLocation<Value>,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues(),
    as: Value.Type
  ) -> Value? {
    self.value(at: location, in: environment)
  }

  public func value<Value>(
    at location: some CactusMemoryLocation<Value>,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) -> Value? {
    self.values.withLock { $0[self.key(for: location, in: environment)] as? Value }
  }

  public func store<Value>(
    value: Value,
    at location: some CactusMemoryLocation<Value>,
    in environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.values.withLock { $0[self.key(for: location, in: environment)] = value }
  }

  private func key(
    for location: some CactusMemoryLocation,
    in environment: CactusEnvironmentValues
  ) -> AnyHashableSendable {
    AnyHashableSendable(location.key(in: environment))
  }
}
