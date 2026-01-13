import Foundation

// MARK: - Factory

extension CactusMemoryLocation {
  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Bool> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Int> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Double> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<String> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<[String]> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<URL> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Data> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Date> {
    AppStorageMemoryLocation(key, store: store)
  }

  @_disfavoredOverload
  public static func appStorage<Value: Codable>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage<Value: RawRepresentable<Int>>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage<Value: RawRepresentable<String>>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Bool?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Int?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Double?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<String?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<[String]?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<URL?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Data?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
  where Self == AppStorageMemoryLocation<Date?> {
    AppStorageMemoryLocation(key, store: store)
  }

  @_disfavoredOverload
  public static func appStorage<Value: Codable>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage<Value: RawRepresentable<Int>>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value?> {
    AppStorageMemoryLocation(key, store: store)
  }

  public static func appStorage<Value: RawRepresentable<String>>(
    _ key: String,
    store: UserDefaults? = nil
  ) -> Self where Self == AppStorageMemoryLocation<Value?> {
    AppStorageMemoryLocation(key, store: store)
  }
}

// MARK: - AppStorageMemoryLocation

public struct AppStorageMemoryLocation<Value: Sendable>: CactusMemoryLocation {
  public struct Key: Hashable, Sendable {
    let key: String
    let store: ObjectIdentifier
  }

  private let key: String
  private let lookup: any Lookup<Value>
  private let store: UnsafeTransfer<UserDefaults>?

  fileprivate init(lookup: some Lookup<Value>, key: String, store: UserDefaults?) {
    self.lookup = lookup
    self.key = key
    self.store = store.map(UnsafeTransfer.init)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Bool {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Int {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Double {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == String {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == [String] {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == URL {
    self.init(lookup: URLLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Data {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Date {
    self.init(lookup: CastableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value: Codable {
    self.init(lookup: CodableLookup(), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?)
  where Value: RawRepresentable<Int> {
    self.init(lookup: RawRepresentableLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?)
  where Value: RawRepresentable<String> {
    self.init(lookup: RawRepresentableLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Bool? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Int? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Double? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == String? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == [String]? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == URL? {
    self.init(lookup: OptionalLookup(base: URLLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Data? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init(_ key: String, store: UserDefaults?) where Value == Date? {
    self.init(lookup: OptionalLookup(base: CastableLookup()), key: key, store: store)
  }

  fileprivate init<C: Codable>(_ key: String, store: UserDefaults?) where Value == C? {
    self.init(lookup: OptionalLookup(base: CodableLookup()), key: key, store: store)
  }

  fileprivate init<R: RawRepresentable<Int>>(_ key: String, store: UserDefaults?)
  where Value == R? {
    self.init(
      lookup: OptionalLookup(base: RawRepresentableLookup(base: CastableLookup())),
      key: key,
      store: store
    )
  }

  fileprivate init<R: RawRepresentable<String>>(_ key: String, store: UserDefaults?)
  where Value == R? {
    self.init(
      lookup: OptionalLookup(base: RawRepresentableLookup(base: CastableLookup())),
      key: key,
      store: store
    )
  }

  public func key(in environment: CactusEnvironmentValues) -> Key {
    Key(key: self.key, store: ObjectIdentifier(self.store(in: environment)))
  }

  public func value(
    in environment: CactusEnvironmentValues,
    currentValue: Value
  ) async throws -> Value {
    self.lookup.loadValue(
      from: self.store(in: environment),
      at: self.key,
      default: currentValue
    ) ?? currentValue
  }

  public func save(value: Value, in environment: CactusEnvironmentValues) async throws {
    self.lookup.saveValue(value, to: self.store(in: environment), at: self.key)
  }

  private func store(in environment: CactusEnvironmentValues) -> UserDefaults {
    self.store?.value ?? environment.defaultAppStorage
  }
}

// MARK: - Lookup

private protocol Lookup<Value>: Sendable {
  associatedtype Value: Sendable

  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Value?
  ) -> Value?

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String)
}

private struct CastableLookup<Value: Sendable>: Lookup {
  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Value?
  ) -> Value? {
    guard let value = store.object(forKey: key) as? Value else {
      store.set(defaultValue, forKey: key)
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    store.set(newValue, forKey: key)
  }
}

private struct CodableLookup<Value: Codable & Sendable>: Lookup {
  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Value?
  ) -> Value? {
    guard let data = store.data(forKey: key) else {
      if let value = defaultValue, let encoded = try? JSONEncoder().encode(value) {
        store.set(encoded, forKey: key)
      }
      return defaultValue
    }
    return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    if let encoded = try? JSONEncoder().encode(newValue) {
      store.set(encoded, forKey: key)
    }
  }
}

private struct URLLookup: Lookup {
  typealias Value = URL

  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: URL?
  ) -> URL? {
    guard let value = store.url(forKey: key) else {
      store.set(defaultValue, forKey: key)
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: URL, to store: UserDefaults, at key: String) {
    store.set(newValue, forKey: key)
  }
}

private struct RawRepresentableLookup<Value: RawRepresentable & Sendable, Base: Lookup>: Lookup
where Value.RawValue == Base.Value {
  let base: Base

  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Value?
  ) -> Value? {
    self.base.loadValue(from: store, at: key, default: defaultValue?.rawValue)
      .flatMap(Value.init(rawValue:))
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    self.base.saveValue(newValue.rawValue, to: store, at: key)
  }
}

private struct OptionalLookup<Base: Lookup>: Lookup {
  let base: Base

  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Base.Value??
  ) -> Base.Value?? {
    self.base.loadValue(from: store, at: key, default: defaultValue ?? nil)
      .flatMap(Optional.some)
      ?? .none
  }

  func saveValue(_ newValue: Base.Value?, to store: UserDefaults, at key: String) {
    if let newValue {
      self.base.saveValue(newValue, to: store, at: key)
    } else {
      store.removeObject(forKey: key)
    }
  }
}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var defaultAppStorage: UserDefaults {
    get { self[AppStorageKey.self].value }
    set { self[AppStorageKey.self] = UnsafeTransfer(value: newValue) }
  }

  private enum AppStorageKey: Key {
    static var defaultValue: UnsafeTransfer<UserDefaults> {
      UnsafeTransfer(value: UserDefaults.standard)
    }
  }
}
