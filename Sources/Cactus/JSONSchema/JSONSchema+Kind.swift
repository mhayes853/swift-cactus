extension JSONSchema {
  public enum Kind: Hashable, Sendable {
    case integer
    case string
    case boolean
    case array
    case object
    case number
    case null
    case union([Self])
  }
}

extension JSONSchema.Kind: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .union(let types): try container.encode(types)
    case .integer: try container.encode("integer")
    case .string: try container.encode("string")
    case .boolean: try container.encode("boolean")
    case .array: try container.encode("array")
    case .object: try container.encode("object")
    case .number: try container.encode("number")
    case .null: try container.encode("null")
    }
  }
}

extension JSONSchema.Kind: Decodable {
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
          debugDescription: "Invalid schema type."
        )
      }
    } else if let types = try? container.decode([Self].self) {
      self = .union(types)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid schema type."
      )
    }
  }
}

extension JSONSchema.Kind: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Self...) {
    self = .union(elements)
  }
}
