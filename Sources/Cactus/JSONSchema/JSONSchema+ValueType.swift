// MARK: - ValueType

extension JSONSchema {
  /// A type-identifier for a ``JSONSchema`` value.
  public struct ValueType: Hashable, Sendable, OptionSet {
    public var rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// An integer type.
    public static let integer = Self(rawValue: 1 << 0)

    /// A string type.
    public static let string = Self(rawValue: 1 << 1)

    /// A boolean type.
    public static let boolean = Self(rawValue: 1 << 2)

    /// An array type.
    public static let array = Self(rawValue: 1 << 3)

    /// An object type.
    public static let object = Self(rawValue: 1 << 4)

    /// A number type.
    public static let number = Self(rawValue: 1 << 5)

    /// A null type.
    public static let null = Self(rawValue: 1 << 6)
  }
}

// MARK: - ExpressibleByArrayLiteral

extension JSONSchema.ValueType: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Self...) {
    self.init(elements)
  }
}

// MARK: - Encodable

extension JSONSchema.ValueType: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .integer: try container.encode("integer")
    case .string: try container.encode("string")
    case .boolean: try container.encode("boolean")
    case .array: try container.encode("array")
    case .object: try container.encode("object")
    case .number: try container.encode("number")
    case .null: try container.encode("null")
    default:
      let allTypes = [Self.integer, .string, .boolean, .array, .object, .number, .null]
      try container.encode(allTypes.filter { self.contains($0) })
    }
  }
}

// MARK: - Decodable

extension JSONSchema.ValueType: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      switch string {
      case "integer": self = .integer
      case "string": self = .string
      case "boolean": self = .boolean
      case "array": self = .array
      case "object": self = .object
      case "number": self = .number
      case "null": self = .null
      default:
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Invalid schema type"
        )
      }
    } else if let array = try? container.decode([Self].self) {
      self.init(array)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid schema type"
      )
    }
  }
}
