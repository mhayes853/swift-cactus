// MARK: - Value

extension JSONSchema {
  /// A value for a ``JSONSchema``.
  public enum Value: Hashable, Sendable {
    /// A string value.
    case string(String)

    /// A boolean value.
    case boolean(Bool)

    /// An array value.
    case array([Self])

    /// An object value.
    case object([String: Self])

    /// A numerical value.
    case number(Double)

    /// An integer value.
    case integer(Int)

    /// A null value.
    case null

    /// The ``ValueType`` of this value.
    public var type: ValueType {
      switch self {
      case .string: .string
      case .boolean: .boolean
      case .array: .array
      case .object: .object
      case .number: .number
      case .integer: .integer
      case .null: .null
      }
    }
  }
}

// MARK: - Encodable

extension JSONSchema.Value: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let array): try container.encode(array)
    case .boolean(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .number(let number): try container.encode(number)
    case .integer(let integer): try container.encode(integer)
    case .object(let object): try container.encode(object)
    case .string(let string): try container.encode(string)
    }
  }
}

// MARK: - Decodable

extension JSONSchema.Value: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if let integer = try? container.decode(Int.self) {
      self = .integer(integer)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([Self].self) {
      self = .array(array)
    } else if let object = try? container.decode([String: Self].self) {
      self = .object(object)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value.")
    }
  }
}

// MARK: - ExpressibleByStringLiteral

extension JSONSchema.Value: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

// MARK: - ExpressibleByBooleanLiteral

extension JSONSchema.Value: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .boolean(value)
  }
}

// MARK: - ExpressibleByFloatLiteral

extension JSONSchema.Value: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .number(value)
  }
}

// MARK: - ExpressibleByIntegerLiteral

extension JSONSchema.Value: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .integer(value)
  }
}

// MARK: - ExpressibleByArrayLiteral

extension JSONSchema.Value: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Self...) {
    self = .array(elements)
  }
}

// MARK: - ExpressibleByDictionaryLiteral

extension JSONSchema.Value: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, Self)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}
