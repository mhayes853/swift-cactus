import Foundation

// MARK: - Value Encoder

extension JSONSchema.Value {
  /// Encodes `Encodable` values into ``JSONSchema/Value``.
  ///
  /// ```swift
  /// struct Payload: Codable {
  ///   let userID: Int
  ///   let displayName: String
  /// }
  ///
  /// let encoder = JSONSchema.Value.Encoder()
  /// encoder.keyEncodingStrategy = .convertToSnakeCase
  /// let value = try encoder.encode(Payload(userID: 42, displayName: "Blob"))
  /// ```
  public final class Encoder: Sendable {
    /// Strategy for encoding `Date` values.
    public enum DateEncodingStrategy: Sendable {
      /// Defer to `Date.encode(to:)`.
      case deferredToDate
      /// Encode as seconds since 1970.
      case secondsSince1970
      /// Encode as milliseconds since 1970.
      case millisecondsSince1970
      /// Encode as an ISO8601 string.
      case iso8601
      /// Encode as a string using the provided formatter.
      case formatted(DateFormatter)
      /// Encode using a custom closure.
      case custom(@Sendable (Date, any Swift.Encoder) throws -> Void)
    }

    /// Strategy for encoding `Data` values.
    public enum DataEncodingStrategy: Sendable {
      /// Defer to `Data.encode(to:)`.
      case deferredToData
      /// Encode as a base64 string.
      case base64
      /// Encode using a custom closure.
      case custom(@Sendable (Data, any Swift.Encoder) throws -> Void)
    }

    /// Strategy for encoding non-conforming floating point values.
    public enum NonConformingFloatEncodingStrategy: Sendable {
      /// Throw on non-conforming values such as `NaN` and infinity.
      case `throw`
      /// Convert non-conforming values to strings.
      case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// Strategy for encoding keyed container keys.
    public enum KeyEncodingStrategy: Sendable {
      /// Use keys exactly as declared.
      case useDefaultKeys
      /// Convert keys from camelCase to snake_case.
      case convertToSnakeCase
      /// Transform keys using a custom closure.
      case custom(@Sendable ([any CodingKey]) -> any CodingKey)
    }

    private struct State {
      var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
      var dataEncodingStrategy: DataEncodingStrategy = .base64
      var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw
      var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
      var userInfo: [CodingUserInfoKey: any Sendable] = [:]
    }

    private let state = Lock(State())

    /// The strategy to use for encoding `Date` values.
    ///
    /// Defaults to `.deferredToDate`.
    public var dateEncodingStrategy: DateEncodingStrategy {
      get { self.state.withLock { $0.dateEncodingStrategy } }
      set { self.state.withLock { $0.dateEncodingStrategy = newValue } }
    }

    /// The strategy to use for encoding `Data` values.
    ///
    /// Defaults to `.base64`.
    public var dataEncodingStrategy: DataEncodingStrategy {
      get { self.state.withLock { $0.dataEncodingStrategy } }
      set { self.state.withLock { $0.dataEncodingStrategy = newValue } }
    }

    /// The strategy to use for encoding non-conforming floating point values.
    ///
    /// Defaults to `.throw`.
    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy {
      get { self.state.withLock { $0.nonConformingFloatEncodingStrategy } }
      set { self.state.withLock { $0.nonConformingFloatEncodingStrategy = newValue } }
    }

    /// The strategy to use for encoding keyed container keys.
    ///
    /// Defaults to `.useDefaultKeys`.
    public var keyEncodingStrategy: KeyEncodingStrategy {
      get { self.state.withLock { $0.keyEncodingStrategy } }
      set { self.state.withLock { $0.keyEncodingStrategy = newValue } }
    }

    /// Contextual information to expose during encoding.
    public var userInfo: [CodingUserInfoKey: any Sendable] {
      get { self.state.withLock { $0.userInfo } }
      set { self.state.withLock { $0.userInfo = newValue } }
    }

    public init() {}

    /// Encodes a value into a ``JSONSchema/Value`` tree.
    ///
    /// - Parameter value: The `Encodable` value to encode.
    /// - Returns: The encoded ``JSONSchema/Value``.
    public func encode<T: Encodable>(_ value: T) throws -> JSONSchema.Value {
      let options = self.state.withLock { state in
        _ValueEncodingOptions(
          dateEncodingStrategy: state.dateEncodingStrategy,
          dataEncodingStrategy: state.dataEncodingStrategy,
          nonConformingFloatEncodingStrategy: state.nonConformingFloatEncodingStrategy,
          keyEncodingStrategy: state.keyEncodingStrategy,
          userInfo: state.userInfo
        )
      }

      let box = _ValueBox()
      let encoder = _ValueEncoder(
        options: options,
        codingPath: [],
        assign: { box.value = $0 }
      )
      try value.encode(to: encoder)
      guard let encoded = box.value else {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: [],
            debugDescription: "Top-level value did not encode any output."
          )
        )
      }
      return encoded
    }
  }
}

private struct _ValueEncodingOptions {
  var dateEncodingStrategy: JSONSchema.Value.Encoder.DateEncodingStrategy
  var dataEncodingStrategy: JSONSchema.Value.Encoder.DataEncodingStrategy
  var nonConformingFloatEncodingStrategy:
    JSONSchema.Value.Encoder.NonConformingFloatEncodingStrategy
  var keyEncodingStrategy: JSONSchema.Value.Encoder.KeyEncodingStrategy
  var userInfo: [CodingUserInfoKey: any Sendable]

  var encoderUserInfo: [CodingUserInfoKey: Any] {
    Dictionary(uniqueKeysWithValues: self.userInfo.map { ($0.key, $0.value as Any) })
  }
}

private final class _ValueBox {
  var value: JSONSchema.Value?
}

private final class _ValueEncoder: Swift.Encoder {
  let options: _ValueEncodingOptions
  var codingPath: [any CodingKey]
  let userInfo: [CodingUserInfoKey: Any]
  private let assign: (JSONSchema.Value) -> Void

  init(
    options: _ValueEncodingOptions,
    codingPath: [any CodingKey],
    assign: @escaping (JSONSchema.Value) -> Void
  ) {
    self.options = options
    self.codingPath = codingPath
    self.userInfo = options.encoderUserInfo
    self.assign = assign
  }

  fileprivate func transformedKey(_ key: any CodingKey) -> String {
    switch self.options.keyEncodingStrategy {
    case .useDefaultKeys:
      return key.stringValue
    case .convertToSnakeCase:
      return _convertToSnakeCase(key.stringValue)
    case .custom(let closure):
      return closure(self.codingPath + [key]).stringValue
    }
  }

  fileprivate func nestedEncoder(
    for pathElement: any CodingKey,
    assign: @escaping (JSONSchema.Value) -> Void
  )
    -> _ValueEncoder
  {
    _ValueEncoder(
      options: self.options,
      codingPath: self.codingPath + [pathElement],
      assign: assign
    )
  }

  func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    let storage = _ObjectStorage()
    self.assign(.object([:]))
    return KeyedEncodingContainer(
      _KeyedValueEncodingContainer<Key>(encoder: self, storage: storage, assign: self.assign)
    )
  }

  func unkeyedContainer() -> any UnkeyedEncodingContainer {
    let storage = _ArrayStorage()
    self.assign(.array([]))
    return _UnkeyedValueEncodingContainer(encoder: self, storage: storage, assign: self.assign)
  }

  func singleValueContainer() -> any SingleValueEncodingContainer {
    _SingleValueValueEncodingContainer(encoder: self, assign: self.assign)
  }
}

private final class _ObjectStorage {
  var object = [String: JSONSchema.Value]()
}

private final class _ArrayStorage {
  var array = [JSONSchema.Value]()
}

private struct _KeyedValueEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  var codingPath: [any CodingKey] { self.encoder.codingPath }

  private let encoder: _ValueEncoder
  private let storage: _ObjectStorage
  private let assign: (JSONSchema.Value) -> Void

  init(
    encoder: _ValueEncoder,
    storage: _ObjectStorage,
    assign: @escaping (JSONSchema.Value) -> Void
  ) {
    self.encoder = encoder
    self.storage = storage
    self.assign = assign
  }

  private func set(_ value: JSONSchema.Value, for key: Key) {
    self.storage.object[self.encoder.transformedKey(key)] = value
    self.assign(.object(self.storage.object))
  }

  func encodeNil(forKey key: Key) throws {
    self.set(.null, for: key)
  }

  func encode(_ value: Bool, forKey key: Key) throws { self.set(.boolean(value), for: key) }
  func encode(_ value: String, forKey key: Key) throws { self.set(.string(value), for: key) }
  func encode(_ value: Double, forKey key: Key) throws {
    self.set(try self.encodeDouble(value), for: key)
  }
  func encode(_ value: Float, forKey key: Key) throws {
    self.set(try self.encodeFloat(value), for: key)
  }
  func encode(_ value: Int, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: Int8, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: Int16, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: Int32, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: Int64, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: UInt, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: UInt8, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: UInt16, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: UInt32, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }
  func encode(_ value: UInt64, forKey key: Key) throws {
    self.set(try _encodeInteger(value, codingPath: self.codingPath + [key]), for: key)
  }

  func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
    let keyName = self.encoder.transformedKey(key)
    let storage = self.storage
    let assign = self.assign

    if let date = value as? Date {
      storage.object[keyName] = try _encodeDate(
        date,
        strategy: self.encoder.options.dateEncodingStrategy,
        codingPath: self.codingPath + [key]
      )
      assign(.object(storage.object))
      return
    }
    if let data = value as? Data {
      storage.object[keyName] = try _encodeData(
        data,
        strategy: self.encoder.options.dataEncodingStrategy,
        codingPath: self.codingPath + [key]
      )
      assign(.object(storage.object))
      return
    }

    let nested = self.encoder.nestedEncoder(for: key) { encoded in
      storage.object[keyName] = encoded
      assign(.object(storage.object))
    }
    try value.encode(to: nested)
  }

  func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey>
  where NestedKey: CodingKey {
    let keyName = self.encoder.transformedKey(key)
    let storage = self.storage
    let assign = self.assign
    let nested = self.encoder.nestedEncoder(for: key) { encoded in
      storage.object[keyName] = encoded
      assign(.object(storage.object))
    }
    return nested.container(keyedBy: keyType)
  }

  func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
    let keyName = self.encoder.transformedKey(key)
    let storage = self.storage
    let assign = self.assign
    let nested = self.encoder.nestedEncoder(for: key) { encoded in
      storage.object[keyName] = encoded
      assign(.object(storage.object))
    }
    return nested.unkeyedContainer()
  }

  func superEncoder() -> any Swift.Encoder {
    let superKey = _SuperCodingKey()
    let keyName = self.encoder.transformedKey(superKey)
    let storage = self.storage
    let assign = self.assign
    return self.encoder.nestedEncoder(for: superKey) { encoded in
      storage.object[keyName] = encoded
      assign(.object(storage.object))
    }
  }

  func superEncoder(forKey key: Key) -> any Swift.Encoder {
    let keyName = self.encoder.transformedKey(key)
    let storage = self.storage
    let assign = self.assign
    return self.encoder.nestedEncoder(for: key) { encoded in
      storage.object[keyName] = encoded
      assign(.object(storage.object))
    }
  }

  private func encodeDouble(_ value: Double) throws -> JSONSchema.Value {
    if value.isFinite {
      return _encodeFiniteNumber(value)
    }
    switch self.encoder.options.nonConformingFloatEncodingStrategy {
    case .throw:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Unable to encode non-conforming floating point value."
        )
      )
    case .convertToString(let positiveInfinity, let negativeInfinity, let nan):
      if value.isNaN { return .string(nan) }
      if value == .infinity { return .string(positiveInfinity) }
      return .string(negativeInfinity)
    }
  }

  private func encodeFloat(_ value: Float) throws -> JSONSchema.Value {
    try self.encodeDouble(Double(value))
  }
}

private struct _UnkeyedValueEncodingContainer: UnkeyedEncodingContainer {
  var codingPath: [any CodingKey] { self.encoder.codingPath }
  var count: Int { self.storage.array.count }

  private let encoder: _ValueEncoder
  private let storage: _ArrayStorage
  private let assign: (JSONSchema.Value) -> Void

  init(encoder: _ValueEncoder, storage: _ArrayStorage, assign: @escaping (JSONSchema.Value) -> Void)
  {
    self.encoder = encoder
    self.storage = storage
    self.assign = assign
  }

  private mutating func append(_ value: JSONSchema.Value) {
    self.storage.array.append(value)
    self.assign(.array(self.storage.array))
  }

  mutating func encodeNil() throws { self.append(.null) }
  mutating func encode(_ value: Bool) throws { self.append(.boolean(value)) }
  mutating func encode(_ value: String) throws { self.append(.string(value)) }
  mutating func encode(_ value: Double) throws { self.append(try self.encodeDouble(value)) }
  mutating func encode(_ value: Float) throws { self.append(try self.encodeDouble(Double(value))) }
  mutating func encode(_ value: Int) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: Int8) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: Int16) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: Int32) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: Int64) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: UInt) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: UInt8) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: UInt16) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: UInt32) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }
  mutating func encode(_ value: UInt64) throws {
    let indexKey = _IndexCodingKey(intValue: self.count)
    self.append(try _encodeInteger(value, codingPath: self.codingPath + [indexKey]))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let index = self.count
    let indexKey = _IndexCodingKey(intValue: index)
    let storage = self.storage
    let assign = self.assign
    if let date = value as? Date {
      self.append(
        try _encodeDate(
          date,
          strategy: self.encoder.options.dateEncodingStrategy,
          codingPath: self.codingPath + [indexKey]
        )
      )
      return
    }
    if let data = value as? Data {
      self.append(
        try _encodeData(
          data,
          strategy: self.encoder.options.dataEncodingStrategy,
          codingPath: self.codingPath + [indexKey]
        )
      )
      return
    }
    let nested = self.encoder.nestedEncoder(for: indexKey) { encoded in
      storage.array[index] = encoded
      assign(.array(storage.array))
    }
    self.append(.null)
    try value.encode(to: nested)
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey>
  where NestedKey: CodingKey {
    let index = self.count
    let storage = self.storage
    let assign = self.assign
    self.append(.object([:]))
    let nested = self.encoder.nestedEncoder(for: _IndexCodingKey(intValue: index)) { encoded in
      storage.array[index] = encoded
      assign(.array(storage.array))
    }
    return nested.container(keyedBy: keyType)
  }

  mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    let index = self.count
    let storage = self.storage
    let assign = self.assign
    self.append(.array([]))
    let nested = self.encoder.nestedEncoder(for: _IndexCodingKey(intValue: index)) { encoded in
      storage.array[index] = encoded
      assign(.array(storage.array))
    }
    return nested.unkeyedContainer()
  }

  mutating func superEncoder() -> any Swift.Encoder {
    let index = self.count
    let storage = self.storage
    let assign = self.assign
    self.append(.null)
    return self.encoder.nestedEncoder(for: _IndexCodingKey(intValue: index)) { encoded in
      storage.array[index] = encoded
      assign(.array(storage.array))
    }
  }

  private func encodeDouble(_ value: Double) throws -> JSONSchema.Value {
    if value.isFinite {
      return _encodeFiniteNumber(value)
    }
    switch self.encoder.options.nonConformingFloatEncodingStrategy {
    case .throw:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Unable to encode non-conforming floating point value."
        )
      )
    case .convertToString(let positiveInfinity, let negativeInfinity, let nan):
      if value.isNaN { return .string(nan) }
      if value == .infinity { return .string(positiveInfinity) }
      return .string(negativeInfinity)
    }
  }
}

private struct _SingleValueValueEncodingContainer: SingleValueEncodingContainer {
  var codingPath: [any CodingKey] { self.encoder.codingPath }

  private let encoder: _ValueEncoder
  private let assign: (JSONSchema.Value) -> Void

  init(encoder: _ValueEncoder, assign: @escaping (JSONSchema.Value) -> Void) {
    self.encoder = encoder
    self.assign = assign
  }

  mutating func encodeNil() throws { self.assign(.null) }
  mutating func encode(_ value: Bool) throws { self.assign(.boolean(value)) }
  mutating func encode(_ value: String) throws { self.assign(.string(value)) }
  mutating func encode(_ value: Double) throws { self.assign(try self.encodeDouble(value)) }
  mutating func encode(_ value: Float) throws { self.assign(try self.encodeDouble(Double(value))) }
  mutating func encode(_ value: Int) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: Int8) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: Int16) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: Int32) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: Int64) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: UInt) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: UInt8) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: UInt16) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: UInt32) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }
  mutating func encode(_ value: UInt64) throws {
    self.assign(try _encodeInteger(value, codingPath: self.codingPath))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    if let date = value as? Date {
      self.assign(
        try _encodeDate(
          date,
          strategy: self.encoder.options.dateEncodingStrategy,
          codingPath: self.codingPath
        )
      )
      return
    }
    if let data = value as? Data {
      self.assign(
        try _encodeData(
          data,
          strategy: self.encoder.options.dataEncodingStrategy,
          codingPath: self.codingPath
        )
      )
      return
    }

    let box = _ValueBox()
    let nested = _ValueEncoder(
      options: self.encoder.options,
      codingPath: self.codingPath,
      assign: { box.value = $0 }
    )
    try value.encode(to: nested)
    guard let encoded = box.value else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Value did not encode any output."
        )
      )
    }
    self.assign(encoded)
  }

  private func encodeDouble(_ value: Double) throws -> JSONSchema.Value {
    if value.isFinite {
      return _encodeFiniteNumber(value)
    }
    switch self.encoder.options.nonConformingFloatEncodingStrategy {
    case .throw:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Unable to encode non-conforming floating point value."
        )
      )
    case .convertToString(let positiveInfinity, let negativeInfinity, let nan):
      if value.isNaN { return .string(nan) }
      if value == .infinity { return .string(positiveInfinity) }
      return .string(negativeInfinity)
    }
  }
}

private func _encodeDate(
  _ date: Date,
  strategy: JSONSchema.Value.Encoder.DateEncodingStrategy,
  codingPath: [any CodingKey]
) throws -> JSONSchema.Value {
  switch strategy {
  case .deferredToDate:
    let box = _ValueBox()
    let encoder = _ValueEncoder(
      options: _ValueEncodingOptions(
        dateEncodingStrategy: strategy,
        dataEncodingStrategy: .base64,
        nonConformingFloatEncodingStrategy: .throw,
        keyEncodingStrategy: .useDefaultKeys,
        userInfo: [:]
      ),
      codingPath: codingPath,
      assign: { box.value = $0 }
    )
    try date.encode(to: encoder)
    guard let value = box.value else {
      throw EncodingError.invalidValue(
        date,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Date did not encode a value."
        )
      )
    }
    return value
  case .secondsSince1970:
    return _encodeFiniteNumber(date.timeIntervalSince1970)
  case .millisecondsSince1970:
    return _encodeFiniteNumber(date.timeIntervalSince1970 * 1000)
  case .iso8601:
    return .string(_makeISO8601Formatter().string(from: date))
  case .formatted(let formatter):
    return .string(formatter.string(from: date))
  case .custom(let closure):
    let box = _ValueBox()
    let encoder = _ValueEncoder(
      options: _ValueEncodingOptions(
        dateEncodingStrategy: strategy,
        dataEncodingStrategy: .base64,
        nonConformingFloatEncodingStrategy: .throw,
        keyEncodingStrategy: .useDefaultKeys,
        userInfo: [:]
      ),
      codingPath: codingPath,
      assign: { box.value = $0 }
    )
    try closure(date, encoder)
    guard let value = box.value else {
      throw EncodingError.invalidValue(
        date,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Custom date strategy did not encode a value."
        )
      )
    }
    return value
  }
}

private func _encodeData(
  _ data: Data,
  strategy: JSONSchema.Value.Encoder.DataEncodingStrategy,
  codingPath: [any CodingKey]
) throws -> JSONSchema.Value {
  switch strategy {
  case .deferredToData:
    return .array(data.map { .integer(Int($0)) })
  case .base64:
    return .string(data.base64EncodedString())
  case .custom(let closure):
    let box = _ValueBox()
    let encoder = _ValueEncoder(
      options: _ValueEncodingOptions(
        dateEncodingStrategy: .deferredToDate,
        dataEncodingStrategy: strategy,
        nonConformingFloatEncodingStrategy: .throw,
        keyEncodingStrategy: .useDefaultKeys,
        userInfo: [:]
      ),
      codingPath: codingPath,
      assign: { box.value = $0 }
    )
    try closure(data, encoder)
    guard let value = box.value else {
      throw EncodingError.invalidValue(
        data,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Custom data strategy did not encode a value."
        )
      )
    }
    return value
  }
}

private func _makeISO8601Formatter() -> ISO8601DateFormatter {
  ISO8601DateFormatter()
}

private struct _IndexCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = Int(stringValue)
  }

  init(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private struct _SuperCodingKey: CodingKey {
  var stringValue: String { "super" }
  var intValue: Int? { nil }
  init?(stringValue: String) { return nil }
  init?(intValue: Int) { return nil }
  init() {}
}

private func _convertToSnakeCase(_ stringKey: String) -> String {
  guard !stringKey.isEmpty else { return stringKey }

  var words = [Range<String.Index>]()
  var wordStart = stringKey.startIndex
  var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex

  while let upperCaseRange = stringKey.rangeOfCharacter(
    from: CharacterSet.uppercaseLetters,
    options: [],
    range: searchRange
  ) {
    let untilUpperCase = wordStart..<upperCaseRange.lowerBound
    words.append(untilUpperCase)

    searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
    guard
      let lowerCaseRange = stringKey.rangeOfCharacter(
        from: CharacterSet.lowercaseLetters,
        options: [],
        range: searchRange
      )
    else {
      wordStart = searchRange.lowerBound
      break
    }

    let nextAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
    if lowerCaseRange.lowerBound == nextAfterCapital {
      wordStart = upperCaseRange.lowerBound
    } else {
      let beforeLower = stringKey.index(before: lowerCaseRange.lowerBound)
      words.append(upperCaseRange.lowerBound..<beforeLower)
      wordStart = beforeLower
    }
    searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
  }

  words.append(wordStart..<searchRange.upperBound)
  return words.map { stringKey[$0].lowercased() }.joined(separator: "_")
}

private func _encodeFiniteNumber(_ value: Double) -> JSONSchema.Value {
  if value.rounded(.towardZero) == value,
    value >= Double(Int.min),
    value <= Double(Int.max)
  {
    return .integer(Int(value))
  }
  return .number(value)
}

private func _encodeInteger<T: BinaryInteger>(
  _ value: T,
  codingPath: [any CodingKey]
) throws -> JSONSchema.Value {
  guard let intValue = Int(exactly: value) else {
    throw EncodingError.invalidValue(
      value,
      EncodingError.Context(
        codingPath: codingPath,
        debugDescription: "Integer value is out of range for JSONSchema.Value.integer storage."
      )
    )
  }
  return .integer(intValue)
}
