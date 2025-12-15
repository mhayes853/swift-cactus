@dynamicMemberLookup
@propertyWrapper
public struct MemoryBinding<Value: Sendable>: Sendable {
  public var wrappedValue: Value {
    get { self.location.wrappedValue }
    nonmutating set { self.location.wrappedValue = newValue }
  }

  private let location: any MemoryBindingLocation<Value>

  public var projectedValue: MemoryBinding<Value> {
    self
  }

  private init(location: any MemoryBindingLocation<Value>) {
    self.location = location
  }

  public init(_ memory: Memory<Value>) {
    self.init(location: MemoryWrapperBindingLocation(memory: memory))
  }

  public subscript<Subject>(
    dynamicMember keyPath: WritableKeyPath<Value, Subject> & Sendable
  ) -> MemoryBinding<Subject> where Subject: Sendable {
    func open<L: MemoryBindingLocation<Value>>(
      _ location: L
    ) -> MemoryBinding<Subject> {
      MemoryBinding<Subject>(
        location: AppendKeyPathBindingLocation(base: location, keyPath: keyPath)
      )
    }
    return open(self.location)
  }
}

extension MemoryBinding {
  public init(get: @escaping @Sendable () -> Value, set: @escaping @Sendable (Value) -> Void) {
    self.init(location: ClosureMemoryBindingLocation(get: get, set: set))
  }
}

extension MemoryBinding {
  public static func constant(_ value: Value) -> Self {
    Self(location: ConstantMemoryBindingLocation(value: value))
  }
}

private protocol MemoryBindingLocation<Value>: Sendable {
  associatedtype Value: Sendable
  var wrappedValue: Value { get nonmutating set }
}

private struct MemoryWrapperBindingLocation<Value: Sendable>: MemoryBindingLocation {
  let memory: Memory<Value>

  var wrappedValue: Value {
    get { self.memory.wrappedValue }
    nonmutating set { self.memory.wrappedValue = newValue }
  }
}

private struct AppendKeyPathBindingLocation<
  Value: Sendable,
  Base: MemoryBindingLocation
>: MemoryBindingLocation {
  let base: Base
  let keyPath: WritableKeyPath<Base.Value, Value> & Sendable

  var wrappedValue: Value {
    get { self.base.wrappedValue[keyPath: self.keyPath] }
    nonmutating set {
      var root = self.base.wrappedValue
      root[keyPath: self.keyPath] = newValue
      self.base.wrappedValue = root
    }
  }
}

private struct ConstantMemoryBindingLocation<Value: Sendable>: MemoryBindingLocation {
  let value: Value

  var wrappedValue: Value {
    get { self.value }
    nonmutating set { _ = newValue }
  }
}

private struct ClosureMemoryBindingLocation<Value: Sendable>: MemoryBindingLocation {
  private let getter: @Sendable () -> Value
  private let setter: @Sendable (Value) -> Void

  init(get: @escaping @Sendable () -> Value, set: @escaping @Sendable (Value) -> Void) {
    self.getter = get
    self.setter = set
  }

  var wrappedValue: Value {
    get { self.getter() }
    nonmutating set { self.setter(newValue) }
  }
}
