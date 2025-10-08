// MARK: - SchemaType

extension CactusLanguageModel {
  /// The type of a value in a schema provided to a ``CactusLanguageModel``.
  public enum SchemaType: Hashable, Sendable {
    case integer
    case string
    case boolean
    case array
    case object
    case number
    case null
    case types([Self])
  }
}

extension CactusLanguageModel.SchemaType: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .types(let types): try container.encode(types)
    default: try container.encode(self.stringified)
    }
  }
}

extension CactusLanguageModel.SchemaType: Decodable {
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
      self = .types(array)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid schema type")
    }
  }
}

extension CactusLanguageModel.SchemaType {
  private var stringified: String? {
    switch self {
    case .integer: "integer"
    case .string: "string"
    case .boolean: "boolean"
    case .array: "array"
    case .object: "object"
    case .number: "number"
    case .null: "null"
    case .types: nil
    }
  }
}

// MARK: - SchemaValue

extension CactusLanguageModel {
  /// A value provided in a schema used by a ``CactusLanguageModel``.
  public enum SchemaValue: Hashable, Sendable {
    case string(String)
    case boolean(Bool)
    case array([SchemaValue])
    case object([String: SchemaValue])
    case number(Double)
    case null
  }
}

extension CactusLanguageModel.SchemaValue: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let array): try container.encode(array)
    case .boolean(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .number(let number): try container.encode(number)
    case .object(let object): try container.encode(object)
    case .string(let string): try container.encode(string)
    }
  }
}

extension CactusLanguageModel.SchemaValue: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
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
