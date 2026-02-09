import Foundation

// MARK: - Value Decoder

extension JSONSchema.Value {
  /// Decodes `Decodable` values from ``JSONSchema/Value``.
  ///
  /// ```swift
  /// struct Payload: Codable {
  ///   let userID: Int
  ///   let displayName: String
  /// }
  ///
  /// let value: JSONSchema.Value = ["user_id": 42, "display_name": "Blob"]
  /// let decoder = JSONSchema.Value.Decoder()
  /// decoder.keyDecodingStrategy = .convertFromSnakeCase
  /// let payload = try decoder.decode(Payload.self, from: value)
  /// ```
  public final class Decoder: Sendable {
    /// Strategy for decoding `Date` values.
    public enum DateDecodingStrategy: Sendable {
      /// Defer to `Date.init(from:)`.
      case deferredToDate
      /// Decode from seconds since 1970.
      case secondsSince1970
      /// Decode from milliseconds since 1970.
      case millisecondsSince1970
      /// Decode from an ISO8601 string.
      case iso8601
      /// Decode from a string using the provided formatter.
      case formatted(DateFormatter)
      /// Decode using a custom closure.
      case custom(@Sendable (any Swift.Decoder) throws -> Date)
    }

    /// Strategy for decoding `Data` values.
    public enum DataDecodingStrategy: Sendable {
      /// Defer to `Data.init(from:)`.
      case deferredToData
      /// Decode from a base64 string.
      case base64
      /// Decode using a custom closure.
      case custom(@Sendable (any Swift.Decoder) throws -> Data)
    }

    /// Strategy for decoding non-conforming floating point values.
    public enum NonConformingFloatDecodingStrategy: Sendable {
      /// Throw on non-conforming values.
      case `throw`
      /// Decode configured string tokens into non-conforming values.
      case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// Strategy for decoding keyed container keys.
    public enum KeyDecodingStrategy: Sendable {
      /// Use keys exactly as provided.
      case useDefaultKeys
      /// Convert keys from snake_case to camelCase.
      case convertFromSnakeCase
      /// Transform keys using a custom closure.
      case custom(@Sendable ([any CodingKey]) -> any CodingKey)
    }

    private struct State {
      var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
      var dataDecodingStrategy: DataDecodingStrategy = .base64
      var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw
      var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
      var userInfo: [CodingUserInfoKey: any Sendable] = [:]
    }

    private let state = Lock(State())

    /// The strategy to use for decoding `Date` values.
    ///
    /// Defaults to `.deferredToDate`.
    public var dateDecodingStrategy: DateDecodingStrategy {
      get { self.state.withLock { $0.dateDecodingStrategy } }
      set { self.state.withLock { $0.dateDecodingStrategy = newValue } }
    }

    /// The strategy to use for decoding `Data` values.
    ///
    /// Defaults to `.base64`.
    public var dataDecodingStrategy: DataDecodingStrategy {
      get { self.state.withLock { $0.dataDecodingStrategy } }
      set { self.state.withLock { $0.dataDecodingStrategy = newValue } }
    }

    /// The strategy to use for decoding non-conforming floating point values.
    ///
    /// Defaults to `.throw`.
    public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy {
      get { self.state.withLock { $0.nonConformingFloatDecodingStrategy } }
      set { self.state.withLock { $0.nonConformingFloatDecodingStrategy = newValue } }
    }

    /// The strategy to use for decoding keyed container keys.
    ///
    /// Defaults to `.useDefaultKeys`.
    public var keyDecodingStrategy: KeyDecodingStrategy {
      get { self.state.withLock { $0.keyDecodingStrategy } }
      set { self.state.withLock { $0.keyDecodingStrategy = newValue } }
    }

    /// Contextual information to expose during decoding.
    public var userInfo: [CodingUserInfoKey: any Sendable] {
      get { self.state.withLock { $0.userInfo } }
      set { self.state.withLock { $0.userInfo = newValue } }
    }

    public init() {}

    /// Decodes a value of the requested type from a ``JSONSchema/Value`` tree.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - value: The input ``JSONSchema/Value``.
    /// - Returns: A decoded value of `type`.
    public func decode<T: Decodable>(_ type: T.Type, from value: JSONSchema.Value) throws -> T {
      let options = self.state.withLock { state in
        _ValueDecodingOptions(
          dateDecodingStrategy: state.dateDecodingStrategy,
          dataDecodingStrategy: state.dataDecodingStrategy,
          nonConformingFloatDecodingStrategy: state.nonConformingFloatDecodingStrategy,
          keyDecodingStrategy: state.keyDecodingStrategy,
          userInfo: state.userInfo
        )
      }

      if type == URL.self {
        guard case .string(let string) = value,
          let url = URL(string: string),
          url.scheme != nil
        else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid URL string.")
          )
        }
        return url as! T
      }

      return try T(from: _ValueDecoder(root: value, options: options, codingPath: []))
    }
  }
}

private struct _ValueDecodingOptions {
  var dateDecodingStrategy: JSONSchema.Value.Decoder.DateDecodingStrategy
  var dataDecodingStrategy: JSONSchema.Value.Decoder.DataDecodingStrategy
  var nonConformingFloatDecodingStrategy:
    JSONSchema.Value.Decoder.NonConformingFloatDecodingStrategy
  var keyDecodingStrategy: JSONSchema.Value.Decoder.KeyDecodingStrategy
  var userInfo: [CodingUserInfoKey: any Sendable]

  var decoderUserInfo: [CodingUserInfoKey: Any] {
    Dictionary(uniqueKeysWithValues: self.userInfo.map { ($0.key, $0.value as Any) })
  }
}

private final class _ValueDecoder: Swift.Decoder {
  let root: JSONSchema.Value
  let options: _ValueDecodingOptions
  var codingPath: [any CodingKey]
  let userInfo: [CodingUserInfoKey: Any]

  init(root: JSONSchema.Value, options: _ValueDecodingOptions, codingPath: [any CodingKey]) {
    self.root = root
    self.options = options
    self.codingPath = codingPath
    self.userInfo = options.decoderUserInfo
  }

  func container<Key>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key>
  where Key: CodingKey {
    guard case .object(let object) = self.root else {
      throw DecodingError.typeMismatch(
        [String: JSONSchema.Value].self,
        DecodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Expected object value."
        )
      )
    }
    return KeyedDecodingContainer(
      _KeyedValueDecodingContainer<Key>(decoder: self, object: object)
    )
  }

  func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
    guard case .array(let array) = self.root else {
      throw DecodingError.typeMismatch(
        [JSONSchema.Value].self,
        DecodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Expected array value."
        )
      )
    }
    return _UnkeyedValueDecodingContainer(decoder: self, array: array)
  }

  func singleValueContainer() throws -> any SingleValueDecodingContainer {
    _SingleValueValueDecodingContainer(decoder: self, value: self.root)
  }

  fileprivate func nestedDecoder(
    for value: JSONSchema.Value,
    codingPath: [any CodingKey]
  ) -> _ValueDecoder {
    _ValueDecoder(root: value, options: self.options, codingPath: codingPath)
  }
}

private struct _KeyedValueDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  var codingPath: [any CodingKey] { self.decoder.codingPath }

  let decoder: _ValueDecoder
  let object: [String: JSONSchema.Value]

  var allKeys: [Key] {
    self.object.keys.compactMap {
      Key(stringValue: self.transformedDecodedKey(forRawKey: $0))
    }
  }

  func contains(_ key: Key) -> Bool {
    self.rawKey(for: key) != nil
  }

  private func rawKey(for key: Key) -> String? {
    switch self.decoder.options.keyDecodingStrategy {
    case .useDefaultKeys:
      return self.object[key.stringValue] == nil ? nil : key.stringValue
    case .convertFromSnakeCase:
      return self.object.keys.first {
        self.transformedDecodedKey(forRawKey: $0) == key.stringValue
      }
    case .custom:
      return self.object.keys.first {
        self.transformedDecodedKey(forRawKey: $0) == key.stringValue
      }
    }
  }

  private func transformedDecodedKey(forRawKey rawKey: String) -> String {
    switch self.decoder.options.keyDecodingStrategy {
    case .useDefaultKeys:
      return rawKey
    case .convertFromSnakeCase:
      return _convertFromSnakeCase(rawKey)
    case .custom(let closure):
      return closure(self.codingPath + [_StringCodingKey(stringValue: rawKey)]).stringValue
    }
  }

  private func require(_ key: Key) throws -> JSONSchema.Value {
    guard let rawKey = self.rawKey(for: key), let value = self.object[rawKey] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: self.codingPath + [key],
          debugDescription: "No value associated with key \(key.stringValue)."
        )
      )
    }
    return value
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    guard let rawKey = self.rawKey(for: key), let value = self.object[rawKey] else { return true }
    if case .null = value { return true }
    return false
  }

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try self.decodeValue(for: key).decode(Bool.self)
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try self.decodeValue(for: key).decode(String.self)
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try self.decodeValue(for: key).decode(Double.self)
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try self.decodeValue(for: key).decode(Float.self)
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try self.decodeValue(for: key).decode(Int.self)
  }

  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try self.decodeValue(for: key).decode(Int8.self)
  }

  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try self.decodeValue(for: key).decode(Int16.self)
  }

  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try self.decodeValue(for: key).decode(Int32.self)
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try self.decodeValue(for: key).decode(Int64.self)
  }

  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try self.decodeValue(for: key).decode(UInt.self)
  }

  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try self.decodeValue(for: key).decode(UInt8.self)
  }

  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try self.decodeValue(for: key).decode(UInt16.self)
  }

  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try self.decodeValue(for: key).decode(UInt32.self)
  }

  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try self.decodeValue(for: key).decode(UInt64.self)
  }

  func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
    let value = try self.require(key)
    if type == Date.self {
      return try self.decodeDate(value, for: key) as! T
    }
    if type == Data.self {
      return try self.decodeData(value, for: key) as! T
    }
    if type == URL.self {
      guard case .string(let string) = value,
        let url = URL(string: string),
        url.scheme != nil
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: self.codingPath + [key],
            debugDescription: "Invalid URL string."
          )
        )
      }
      return url as! T
    }
    let decoder = self.decoder.nestedDecoder(for: value, codingPath: self.codingPath + [key])
    return try T(from: decoder)
  }

  func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    try self.decoder.nestedDecoder(for: self.require(key), codingPath: self.codingPath + [key])
      .container(keyedBy: type)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
    try self.decoder.nestedDecoder(for: self.require(key), codingPath: self.codingPath + [key])
      .unkeyedContainer()
  }

  func superDecoder() throws -> any Swift.Decoder {
    self.decoder.nestedDecoder(
      for: .object(self.object),
      codingPath: self.codingPath + [_SuperCodingKey()]
    )
  }

  func superDecoder(forKey key: Key) throws -> any Swift.Decoder {
    self.decoder.nestedDecoder(for: try self.require(key), codingPath: self.codingPath + [key])
  }

  private func decodeValue(for key: Key) throws -> _SingleValueValueDecodingContainer {
    _SingleValueValueDecodingContainer(
      decoder: self.decoder,
      value: try self.require(key),
      codingPath: self.codingPath + [key]
    )
  }

  private func decodeDate(_ value: JSONSchema.Value, for key: Key) throws -> Date {
    let codingPath = self.codingPath + [key]
    switch self.decoder.options.dateDecodingStrategy {
    case .deferredToDate:
      return try Date(from: self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    case .secondsSince1970:
      return Date(
        timeIntervalSince1970: try self.decodeFloatingSeconds(value, codingPath: codingPath)
      )
    case .millisecondsSince1970:
      return Date(
        timeIntervalSince1970: try self.decodeFloatingSeconds(value, codingPath: codingPath) / 1000
      )
    case .iso8601:
      guard case .string(let string) = value, let date = _makeISO8601Formatter().date(from: string)
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected ISO8601 date string."
          )
        )
      }
      return date
    case .formatted(let formatter):
      guard case .string(let string) = value, let date = formatter.date(from: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Date string does not match formatter."
          )
        )
      }
      return date
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    }
  }

  private func decodeData(_ value: JSONSchema.Value, for key: Key) throws -> Data {
    let codingPath = self.codingPath + [key]
    switch self.decoder.options.dataDecodingStrategy {
    case .deferredToData:
      if case .string(let string) = value, let data = Data(base64Encoded: string) {
        return data
      }
      return try Data(from: self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    case .base64:
      guard case .string(let string) = value, let data = Data(base64Encoded: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected base64 data string."
          )
        )
      }
      return data
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    }
  }

  private func decodeFloatingSeconds(_ value: JSONSchema.Value, codingPath: [any CodingKey]) throws
    -> Double
  {
    switch value {
    case .integer(let int): return Double(int)
    case .number(let double): return double
    default:
      throw DecodingError.typeMismatch(
        Double.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected numeric date representation."
        )
      )
    }
  }
}

private struct _UnkeyedValueDecodingContainer: UnkeyedDecodingContainer {
  var codingPath: [any CodingKey] { self.decoder.codingPath }
  var count: Int? { self.array.count }
  var currentIndex: Int = 0
  var isAtEnd: Bool { self.currentIndex >= self.array.count }

  let decoder: _ValueDecoder
  let array: [JSONSchema.Value]

  private mutating func next() throws -> JSONSchema.Value {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(
        JSONSchema.Value.self,
        DecodingError.Context(
          codingPath: self.codingPath + [_IndexCodingKey(intValue: self.currentIndex)],
          debugDescription: "Unkeyed container is at end."
        )
      )
    }
    defer { self.currentIndex += 1 }
    return self.array[self.currentIndex]
  }

  mutating func decodeNil() throws -> Bool {
    let value = try self.next()
    if case .null = value { return true }
    return false
  }

  mutating func decode(_ type: Bool.Type) throws -> Bool {
    try self.nextContainer().decode(Bool.self)
  }
  mutating func decode(_ type: String.Type) throws -> String {
    try self.nextContainer().decode(String.self)
  }
  mutating func decode(_ type: Double.Type) throws -> Double {
    try self.nextContainer().decode(Double.self)
  }
  mutating func decode(_ type: Float.Type) throws -> Float {
    try self.nextContainer().decode(Float.self)
  }
  mutating func decode(_ type: Int.Type) throws -> Int { try self.nextContainer().decode(Int.self) }
  mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try self.nextContainer().decode(Int8.self)
  }
  mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try self.nextContainer().decode(Int16.self)
  }
  mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try self.nextContainer().decode(Int32.self)
  }
  mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try self.nextContainer().decode(Int64.self)
  }
  mutating func decode(_ type: UInt.Type) throws -> UInt {
    try self.nextContainer().decode(UInt.self)
  }
  mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try self.nextContainer().decode(UInt8.self)
  }
  mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try self.nextContainer().decode(UInt16.self)
  }
  mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try self.nextContainer().decode(UInt32.self)
  }
  mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try self.nextContainer().decode(UInt64.self)
  }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    let value = try self.next()
    let codingPath = self.codingPath + [_IndexCodingKey(intValue: self.currentIndex - 1)]

    if type == Date.self {
      return try self.decodeDate(value, codingPath: codingPath) as! T
    }
    if type == Data.self {
      return try self.decodeData(value, codingPath: codingPath) as! T
    }
    if type == URL.self {
      guard case .string(let string) = value,
        let url = URL(string: string),
        url.scheme != nil
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid URL string.")
        )
      }
      return url as! T
    }
    return try T(from: self.decoder.nestedDecoder(for: value, codingPath: codingPath))
  }

  mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey>
  where NestedKey: CodingKey {
    let value = try self.next()
    let codingPath = self.codingPath + [_IndexCodingKey(intValue: self.currentIndex - 1)]
    return try self.decoder.nestedDecoder(for: value, codingPath: codingPath)
      .container(keyedBy: type)
  }

  mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
    let value = try self.next()
    let codingPath = self.codingPath + [_IndexCodingKey(intValue: self.currentIndex - 1)]
    return try self.decoder.nestedDecoder(for: value, codingPath: codingPath).unkeyedContainer()
  }

  mutating func superDecoder() throws -> any Swift.Decoder {
    let value = try self.next()
    let codingPath = self.codingPath + [_IndexCodingKey(intValue: self.currentIndex - 1)]
    return self.decoder.nestedDecoder(for: value, codingPath: codingPath)
  }

  private mutating func nextContainer() throws -> _SingleValueValueDecodingContainer {
    let value = try self.next()
    return _SingleValueValueDecodingContainer(
      decoder: self.decoder,
      value: value,
      codingPath: self.codingPath + [_IndexCodingKey(intValue: self.currentIndex - 1)]
    )
  }

  private func decodeDate(_ value: JSONSchema.Value, codingPath: [any CodingKey]) throws -> Date {
    switch self.decoder.options.dateDecodingStrategy {
    case .deferredToDate:
      return try Date(from: self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    case .secondsSince1970:
      return Date(
        timeIntervalSince1970: try self.decodeFloatingSeconds(value, codingPath: codingPath)
      )
    case .millisecondsSince1970:
      return Date(
        timeIntervalSince1970: try self.decodeFloatingSeconds(value, codingPath: codingPath) / 1000
      )
    case .iso8601:
      guard case .string(let string) = value, let date = _makeISO8601Formatter().date(from: string)
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected ISO8601 date string."
          )
        )
      }
      return date
    case .formatted(let formatter):
      guard case .string(let string) = value, let date = formatter.date(from: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Date string does not match formatter."
          )
        )
      }
      return date
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    }
  }

  private func decodeData(_ value: JSONSchema.Value, codingPath: [any CodingKey]) throws -> Data {
    switch self.decoder.options.dataDecodingStrategy {
    case .deferredToData:
      if case .string(let string) = value, let data = Data(base64Encoded: string) {
        return data
      }
      return try Data(from: self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    case .base64:
      guard case .string(let string) = value, let data = Data(base64Encoded: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected base64 data string."
          )
        )
      }
      return data
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: value, codingPath: codingPath))
    }
  }

  private func decodeFloatingSeconds(
    _ value: JSONSchema.Value,
    codingPath: [any CodingKey]
  ) throws -> Double {
    switch value {
    case .integer(let int): return Double(int)
    case .number(let double): return double
    default:
      throw DecodingError.typeMismatch(
        Double.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected numeric date representation."
        )
      )
    }
  }
}

private struct _SingleValueValueDecodingContainer: SingleValueDecodingContainer {
  let decoder: _ValueDecoder
  let value: JSONSchema.Value
  var codingPath: [any CodingKey]

  init(decoder: _ValueDecoder, value: JSONSchema.Value, codingPath: [any CodingKey]? = nil) {
    self.decoder = decoder
    self.value = value
    self.codingPath = codingPath ?? decoder.codingPath
  }

  func decodeNil() -> Bool {
    if case .null = self.value { return true }
    return false
  }

  func decode(_ type: Bool.Type) throws -> Bool {
    guard case .boolean(let bool) = self.value else { throw self.typeMismatch(Bool.self) }
    return bool
  }

  func decode(_ type: String.Type) throws -> String {
    switch self.value {
    case .string(let string):
      return string
    case .null:
      throw DecodingError.valueNotFound(
        String.self,
        DecodingError.Context(
          codingPath: self.codingPath,
          debugDescription: "Expected String value but found null."
        )
      )
    default:
      throw self.typeMismatch(String.self)
    }
  }

  func decode(_ type: Double.Type) throws -> Double {
    switch self.value {
    case .integer(let integer): return Double(integer)
    case .number(let number): return number
    case .string(let string):
      switch self.decoder.options.nonConformingFloatDecodingStrategy {
      case .throw:
        throw self.typeMismatch(Double.self)
      case .convertFromString(let positiveInfinity, let negativeInfinity, let nan):
        if string == positiveInfinity { return .infinity }
        if string == negativeInfinity { return -.infinity }
        if string == nan { return .nan }
        throw self.typeMismatch(Double.self)
      }
    default:
      throw self.typeMismatch(Double.self)
    }
  }

  func decode(_ type: Float.Type) throws -> Float {
    Float(try self.decode(Double.self))
  }

  func decode(_ type: Int.Type) throws -> Int { try self.integer(Int.self) }
  func decode(_ type: Int8.Type) throws -> Int8 { try self.integer(Int8.self) }
  func decode(_ type: Int16.Type) throws -> Int16 { try self.integer(Int16.self) }
  func decode(_ type: Int32.Type) throws -> Int32 { try self.integer(Int32.self) }
  func decode(_ type: Int64.Type) throws -> Int64 { try self.integer(Int64.self) }
  func decode(_ type: UInt.Type) throws -> UInt { try self.integer(UInt.self) }
  func decode(_ type: UInt8.Type) throws -> UInt8 { try self.integer(UInt8.self) }
  func decode(_ type: UInt16.Type) throws -> UInt16 { try self.integer(UInt16.self) }
  func decode(_ type: UInt32.Type) throws -> UInt32 { try self.integer(UInt32.self) }
  func decode(_ type: UInt64.Type) throws -> UInt64 { try self.integer(UInt64.self) }

  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    if type == Date.self {
      return try self.decodeDate() as! T
    }
    if type == Data.self {
      return try self.decodeData() as! T
    }
    if type == URL.self {
      guard case .string(let string) = self.value,
        let url = URL(string: string),
        url.scheme != nil
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: self.codingPath,
            debugDescription: "Invalid URL string."
          )
        )
      }
      return url as! T
    }
    return try T(from: self.decoder.nestedDecoder(for: self.value, codingPath: self.codingPath))
  }

  private func decodeDate() throws -> Date {
    switch self.decoder.options.dateDecodingStrategy {
    case .deferredToDate:
      return try Date(
        from: self.decoder.nestedDecoder(for: self.value, codingPath: self.codingPath)
      )
    case .secondsSince1970:
      return Date(timeIntervalSince1970: try self.decode(Double.self))
    case .millisecondsSince1970:
      return Date(timeIntervalSince1970: try self.decode(Double.self) / 1000)
    case .iso8601:
      guard case .string(let string) = self.value,
        let date = _makeISO8601Formatter().date(from: string)
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: self.codingPath,
            debugDescription: "Expected ISO8601 date string."
          )
        )
      }
      return date
    case .formatted(let formatter):
      guard case .string(let string) = self.value, let date = formatter.date(from: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: self.codingPath,
            debugDescription: "Date string does not match formatter."
          )
        )
      }
      return date
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: self.value, codingPath: self.codingPath))
    }
  }

  private func decodeData() throws -> Data {
    switch self.decoder.options.dataDecodingStrategy {
    case .deferredToData:
      if case .string(let string) = self.value, let data = Data(base64Encoded: string) {
        return data
      }
      return try Data(
        from: self.decoder.nestedDecoder(for: self.value, codingPath: self.codingPath)
      )
    case .base64:
      guard case .string(let string) = self.value, let data = Data(base64Encoded: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: self.codingPath,
            debugDescription: "Expected base64 data string."
          )
        )
      }
      return data
    case .custom(let closure):
      return try closure(self.decoder.nestedDecoder(for: self.value, codingPath: self.codingPath))
    }
  }

  private func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
    switch self.value {
    case .integer(let int):
      guard let converted = T(exactly: int) else { throw self.typeMismatch(T.self) }
      return converted
    case .number(let number):
      guard number.isFinite,
        number.rounded(.towardZero) == number,
        number >= Double(Int64.min),
        number <= Double(Int64.max),
        let converted = T(exactly: Int64(number))
      else {
        throw self.typeMismatch(T.self)
      }
      return converted
    default:
      throw self.typeMismatch(T.self)
    }
  }

  private func typeMismatch(_ type: Any.Type) -> DecodingError {
    DecodingError.typeMismatch(
      type,
      DecodingError.Context(
        codingPath: self.codingPath,
        debugDescription: "Expected \(type) value."
      )
    )
  }
}

private struct _StringCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = Int(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private func _convertFromSnakeCase(_ key: String) -> String {
  guard !key.isEmpty else { return key }

  guard let firstNonUnderscore = key.firstIndex(where: { $0 != "_" }) else {
    return key
  }

  var lastNonUnderscore = key.index(before: key.endIndex)
  while lastNonUnderscore > firstNonUnderscore && key[lastNonUnderscore] == "_" {
    key.formIndex(before: &lastNonUnderscore)
  }

  let keyRange = firstNonUnderscore...lastNonUnderscore
  let leadingUnderscoreRange = key.startIndex..<firstNonUnderscore
  let trailingUnderscoreRange = key.index(after: lastNonUnderscore)..<key.endIndex

  let components = key[keyRange].split(separator: "_")
  let joinedString: String
  if components.count == 1 {
    joinedString = String(key[keyRange])
  } else {
    joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
  }

  if leadingUnderscoreRange.isEmpty && trailingUnderscoreRange.isEmpty {
    return joinedString
  } else if !leadingUnderscoreRange.isEmpty && !trailingUnderscoreRange.isEmpty {
    return String(key[leadingUnderscoreRange]) + joinedString + String(key[trailingUnderscoreRange])
  } else if !leadingUnderscoreRange.isEmpty {
    return String(key[leadingUnderscoreRange]) + joinedString
  } else {
    return joinedString + String(key[trailingUnderscoreRange])
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
