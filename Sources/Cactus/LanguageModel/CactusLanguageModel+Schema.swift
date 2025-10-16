// MARK: - SchemaType

extension CactusLanguageModel {
  /// The type of a value in a schema provided to a ``CactusLanguageModel``.
  @available(*, deprecated, message: "Use `JSONSchema.Kind` instead.")
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

@available(*, deprecated)
extension CactusLanguageModel.SchemaType: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .types(let types): try container.encode(types)
    default: try container.encode(self.stringified)
    }
  }
}

@available(*, deprecated)
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

@available(*, deprecated)
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
  @available(*, deprecated, message: "Use `JSONSchema.Value` instead.")
  public typealias SchemaValue = JSONSchema.Value
}
