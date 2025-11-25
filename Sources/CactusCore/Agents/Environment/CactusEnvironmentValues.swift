// MARK: - CactusEnvironment

public struct CactusEnvironmentValues {
  private var storage = [StorageKey: Any]()

  public init() {}
}

// MARK: - Storage

extension CactusEnvironmentValues {
  private struct StorageKey: Hashable {
    let type: Any.Type

    var typeName: String {
      CactusCore.typeName(self.type)
    }

    static func == (lhs: StorageKey, rhs: StorageKey) -> Bool {
      lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self.type))
    }
  }
}

// MARK: - Key

extension CactusEnvironmentValues {
  public protocol Key<Value> {
    associatedtype Value: Sendable
    static var defaultValue: Value { get }
  }
}

// MARK: - Subscript

extension CactusEnvironmentValues {
  public subscript<Value>(_ key: (some Key<Value>).Type) -> Value {
    get { (self.storage[StorageKey(type: key)] as? Value) ?? key.defaultValue }
    set { self.storage[StorageKey(type: key)] = newValue }
  }
}

// MARK: - CustomStringConvertible

extension CactusEnvironmentValues: CustomStringConvertible {
  public var description: String {
    let string = self.storage.map { (key, value) in "\(key.typeName) = \(value)" }
      .joined(separator: ", ")
    return "[\(string)]"
  }
}
