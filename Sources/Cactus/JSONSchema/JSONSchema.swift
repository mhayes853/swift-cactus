// MARK: - JSONSchema

public indirect enum JSONSchema: Hashable, Sendable {
  case boolean(Bool)
  case object(Object)
}

// MARK: - Object

extension JSONSchema {
  public struct Object: Hashable, Sendable, Codable {
    public var title: String?
    public var description: String?

    public var type: ValueType?

    public var `default`: Value?
    public var readOnly: Bool?
    public var writeOnly: Bool?
    public var examples: Value?

    public var `enum`: [Value]?
    public var const: Value?

    public var allOf: [JSONSchema]?
    public var anyOf: [JSONSchema]?
    public var oneOf: [JSONSchema]?
    public var not: JSONSchema?

    public var `if`: JSONSchema?
    public var then: JSONSchema?
    public var `else`: JSONSchema?

    public var format: String?

    public init(
      title: String? = nil,
      description: String? = nil,
      type: JSONSchema.ValueType?,
      `default`: JSONSchema.Value? = nil,
      readOnly: Bool? = nil,
      writeOnly: Bool? = nil,
      examples: JSONSchema.Value? = nil,
      `enum`: [JSONSchema.Value]? = nil,
      const: JSONSchema.Value? = nil,
      allOf: [JSONSchema]? = nil,
      anyOf: [JSONSchema]? = nil,
      oneOf: [JSONSchema]? = nil,
      not: JSONSchema? = nil,
      `if`: JSONSchema? = nil,
      then: JSONSchema? = nil,
      `else`: JSONSchema? = nil,
      format: String? = nil
    ) {
      self.title = title
      self.description = description
      self.`default` = `default`
      self.readOnly = readOnly
      self.writeOnly = writeOnly
      self.examples = examples
      self.type = type
      self.`enum` = `enum`
      self.const = const
      self.allOf = allOf
      self.anyOf = anyOf
      self.oneOf = oneOf
      self.not = not
      self.`if` = `if`
      self.then = then
      self.`else` = `else`
      self.format = format
    }
  }

  public static func object(
    title: String? = nil,
    description: String? = nil,
    type: JSONSchema.ValueType?,
    `default`: JSONSchema.Value? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    examples: JSONSchema.Value? = nil,
    `enum`: [JSONSchema.Value]? = nil,
    const: JSONSchema.Value? = nil,
    allOf: [JSONSchema]? = nil,
    anyOf: [JSONSchema]? = nil,
    oneOf: [JSONSchema]? = nil,
    not: JSONSchema? = nil,
    `if`: JSONSchema? = nil,
    then: JSONSchema? = nil,
    `else`: JSONSchema? = nil,
    format: String? = nil
  ) -> Self {
    .object(
      Object(
        title: title,
        description: description,
        type: type,
        default: `default`,
        readOnly: readOnly,
        writeOnly: writeOnly,
        examples: examples,
        enum: `enum`,
        const: const,
        allOf: allOf,
        anyOf: anyOf,
        oneOf: oneOf,
        not: not,
        if: `if`,
        then: then,
        else: `else`,
        format: format
      )
    )
  }
}

// MARK: - Encodable

extension JSONSchema: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .boolean(let bool): try container.encode(bool)
    case .object(let object): try container.encode(SerializeableObject(object: object))
    }
  }
}

// MARK: - Decodable

extension JSONSchema: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if let object = try? container.decode(SerializeableObject.self) {
      self = .object(Object(serializeable: object))
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "JSONSchema must either be a boolean or object."
      )
    }
  }
}

// MARK: - SerializeableObject

private struct SerializeableObject: Codable {
  var type: SchemaType?
  var title: String?
  var description: String?
  var `default`: JSONSchema.Value?
  var readOnly: Bool?
  var writeOnly: Bool?
  var examples: JSONSchema.Value?
  var `enum`: [JSONSchema.Value]?
  var const: JSONSchema.Value?
  var allOf: [JSONSchema]?
  var anyOf: [JSONSchema]?
  var oneOf: [JSONSchema]?
  var not: JSONSchema?
  var `if`: JSONSchema?
  var then: JSONSchema?
  var `else`: JSONSchema?
  var format: String?

  var properties: [Swift.String: JSONSchema]?
  var required: [Swift.String]?
  var minProperties: Int?
  var maxProperties: Int?
  var additionalProperties: JSONSchema?
  var patternProperties: [Swift.String: JSONSchema]?
  var propertyNames: JSONSchema?

  var items: JSONSchema.ValueType.Array.Items?
  var additionalItems: JSONSchema?
  var minItems: Int?
  var maxItems: Int?
  var uniqueItems: Bool?
  var contains: JSONSchema?

  var multipleOf: Double?
  var minimum: Double?
  var exclusiveMinimum: Double?
  var maximum: Double?
  var exclusiveMaximum: Double?

  var minLength: Int?
  var maxLength: Int?
  var pattern: Swift.String?

  init(object: JSONSchema.Object) {
    self.title = object.title
    self.description = object.description
    self.default = object.default
    self.allOf = object.allOf
    self.anyOf = object.anyOf
    self.oneOf = object.oneOf
    self.not = object.not
    self.if = object.if
    self.then = object.then
    self.else = object.else
    self.format = object.format
    self.enum = object.enum
    self.const = object.const

    if let type = object.type {
      self.set(from: type)
    }
  }

  private mutating func set(from valueType: JSONSchema.ValueType, isUnion: Bool = false) {
    switch valueType {
    case .array(let array):
      if !isUnion {
        self.type = .array
      }
      self.items = array.items
      self.additionalItems = array.additionalItems
      self.minItems = array.minItems
      self.maxItems = array.maxItems
      self.uniqueItems = array.uniqueItems
      self.contains = array.contains

    case .number(let number):
      if !isUnion {
        self.type = .number
      }
      self.multipleOf = number.multipleOf
      self.minimum = number.minimum
      self.exclusiveMinimum = number.exclusiveMinimum
      self.maximum = number.maximum
      self.exclusiveMaximum = number.exclusiveMaximum

    case .string(let string):
      if !isUnion {
        self.type = .string
      }
      self.minLength = string.minLength
      self.maxLength = string.maxLength
      self.pattern = string.pattern

    case .null:
      if !isUnion {
        self.type = .null
      }

    case .boolean:
      if !isUnion {
        self.type = .boolean
      }

    case .object(let object):
      if !isUnion {
        self.type = .object
      }
      self.properties = object.properties
      self.patternProperties = object.patternProperties
      self.additionalProperties = object.additionalProperties
      self.minProperties = object.minProperties
      self.maxProperties = object.maxProperties
      self.required = object.required

    case .union(let valueTypes):
      self.type = .types(valueTypes.map(\.schemaType))
      for type in valueTypes {
        self.set(from: type, isUnion: true)
      }
    }
  }
}

extension SerializeableObject {
  enum SchemaType: Hashable, Sendable, Codable {
    case integer
    case string
    case boolean
    case array
    case object
    case number
    case null
    case types([Self])

    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .integer: try container.encode("integer")
      case .string: try container.encode("string")
      case .boolean: try container.encode("boolean")
      case .array: try container.encode("array")
      case .object: try container.encode("object")
      case .number: try container.encode("number")
      case .null: try container.encode("null")
      case .types(let types): try container.encode(types)
      }
    }

    init(from decoder: any Decoder) throws {
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
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Invalid schema type"
        )
      }
    }
  }
}

extension JSONSchema.ValueType {
  fileprivate var schemaType: SerializeableObject.SchemaType {
    switch self {
    case .array: .array
    case .boolean: .boolean
    case .number: .number
    case .null: .null
    case .object: .object
    case .string: .string
    case .union(let valueTypes): .types(valueTypes.map(\.schemaType))
    }
  }
}

extension JSONSchema.Object {
  fileprivate init(serializeable: SerializeableObject) {
    self.init(
      title: serializeable.title,
      description: serializeable.description,
      type: JSONSchema.ValueType(serializeable: serializeable),
      default: serializeable.default,
      readOnly: serializeable.readOnly,
      writeOnly: serializeable.writeOnly,
      examples: serializeable.examples,
      enum: serializeable.enum,
      const: serializeable.const,
      allOf: serializeable.allOf,
      anyOf: serializeable.anyOf,
      oneOf: serializeable.oneOf,
      not: serializeable.not,
      if: serializeable.if,
      then: serializeable.then,
      else: serializeable.else,
      format: serializeable.format
    )
  }
}

extension JSONSchema.ValueType {
  fileprivate init?(serializeable: SerializeableObject) {
    switch serializeable.type {
    case .array:
      self = .array(
        items: serializeable.items,
        minItems: serializeable.minItems,
        maxItems: serializeable.maxItems,
        uniqueItems: serializeable.uniqueItems,
        contains: serializeable.contains
      )
    case .number, .integer:
      self = .number(
        multipleOf: serializeable.multipleOf,
        minimum: serializeable.minimum,
        exclusiveMinimum: serializeable.exclusiveMinimum,
        maximum: serializeable.maximum,
        exclusiveMaximum: serializeable.exclusiveMaximum
      )
    case .string:
      self = .string(
        minLength: serializeable.minLength,
        maxLength: serializeable.maxLength,
        pattern: serializeable.pattern
      )
    case .null:
      self = .null
    case .boolean:
      self = .boolean
    case .object:
      self = .object(
        properties: serializeable.properties,
        required: serializeable.required,
        minProperties: serializeable.minProperties,
        maxProperties: serializeable.maxProperties,
        additionalProperties: serializeable.additionalItems,
        patternProperties: serializeable.patternProperties,
        propertyNames: serializeable.propertyNames
      )
    case .types(let types):
      var union = [Self]()
      for type in types {
        var object = serializeable
        object.type = type
        guard let valueType = Self(serializeable: object) else { continue }
        union.append(valueType)
      }
      self = .union(union)
    default:
      return nil
    }
  }
}
