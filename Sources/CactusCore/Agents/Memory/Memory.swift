@propertyWrapper
public struct Memory<Value: Sendable>: Sendable {
  private let box = LockedBox<Value?>(nil)
  private let _wrappedValue: @Sendable () -> Value

  public var wrappedValue: Value {
    get { self.box.inner.withLock { $0 ?? self._wrappedValue() } }
    nonmutating set { self.box.inner.withLock { $0 = newValue } }
  }

  public init(wrappedValue: @autoclosure @escaping @Sendable () -> Value) {
    self._wrappedValue = wrappedValue
  }
}
