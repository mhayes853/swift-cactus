import Foundation

// MARK: - JSONSchema

/// An enun defining a JSON Schema.
///
/// A valid json schema is either an object or a boolean.
public indirect enum JSONSchema: Hashable, Sendable {
  /// A boolean schema.
  case boolean(Bool)

  /// An object schema.
  case object(Object)
}

// MARK: - Object

extension JSONSchema {
  /// An object schema.
  public struct Object: Hashable, Sendable, Codable {
    /// The title of the schema.
    ///
    /// [10.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.1)
    public var title: String?

    /// The description of the schema.
    ///
    /// [10.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.1)
    public var description: String?

    /// The ``JSONSchema/ValueType`` of the schema.
    ///
    /// [6.1.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.1.1)
    public var type: ValueType?

    /// The default value of the schema.
    ///
    /// [10.2](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.2)
    public var `default`: Value?

    /// Indicates whether the value is managed exclusively by the owning authority.
    ///
    /// [10.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.3)
    public var readOnly: Bool?

    /// Indicates whether the or not the value is present when retrieved from the owning authority.
    ///
    /// [10.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.3)
    public var writeOnly: Bool?

    /// A list of example values.
    ///
    /// [10.4](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-10.4)
    public var examples: [Value]?

    /// A list of allowed values.
    ///
    /// [6.1.2](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.1.2)
    public var `enum`: [Value]?

    /// The only allowed value.
    ///
    /// [6.1.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.1.3)
    public var const: Value?

    /// A list of schemas in which the value must match all of them.
    ///
    /// [6.7.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.7.1)
    public var allOf: [JSONSchema]?

    /// A list of schemas in which the value must match at least one of them.
    ///
    /// [6.7.2](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.7.2)
    public var anyOf: [JSONSchema]?

    /// A list of schemas in which the value must match exactly one of them.
    ///
    /// [6.7.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.7.3)
    public var oneOf: [JSONSchema]?

    /// A schema that the value must not match.
    ///
    /// [6.7.4](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.7.4)
    public var not: JSONSchema?

    /// A schema to use for control flow.
    ///
    /// If the value matches the `if` schema, then it must also match the ``then`` schema. If the
    /// value fails to match the `if` schema, then it must match the ``else`` schema.
    ///
    /// [6.6.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.6.1)
    public var `if`: JSONSchema?

    /// A schema to match against if a value successfully matches against ``if``.
    ///
    /// [6.6.2](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.6.2)
    public var then: JSONSchema?

    /// A schema to match against if a value fails to match against ``if``.
    ///
    /// [6.6.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.6.3)
    public var `else`: JSONSchema?

    /// A string containing information for validating values not confined with the JSON Schema specification.
    ///
    /// [7](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-7)
    public var format: String?

    /// Creates an object schema.
    ///
    /// - Parameters:
    ///   - title: The title of the schema.
    ///   - description: The description of the schema.
    ///   - type: The type of the schema.
    ///   - default: The default value of the schema.
    ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
    ///   - writeOnly: Indicates whether the or not the value is present when retrieved from the owning authority.
    ///   - examples: A list of example values.
    ///   - enum: A list of allowed values.
    ///   - const: The only allowed value.
    ///   - allOf: A list of schemas in which the value must match all of them.
    ///   - anyOf: A list of schemas in which the value must match at least one of them.
    ///   - oneOf: A list of schemas in which the value must match exactly one of them.
    ///   - not: A schema that the value must not match.
    ///   - if: A schema to use for control flow.
    ///   - then: A schema to match against if a value successfully matches against ``if``.
    ///   - else: A schema to match against if a value fails to match against ``if``.
    ///   - format: A string containing information for validating values not confined with the JSON Schema specification.
    public init(
      title: String? = nil,
      description: String? = nil,
      type: ValueType?,
      `default`: Value? = nil,
      readOnly: Bool? = nil,
      writeOnly: Bool? = nil,
      examples: [Value]? = nil,
      `enum`: [Value]? = nil,
      const: Value? = nil,
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

  /// Creates an object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - type: The type of the schema.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the or not the value is present when retrieved from the owning authority.
  ///   - examples: A list of example values.
  ///   - enum: A list of allowed values.
  ///   - const: The only allowed value.
  ///   - allOf: A list of schemas in which the value must match all of them.
  ///   - anyOf: A list of schemas in which the value must match at least one of them.
  ///   - oneOf: A list of schemas in which the value must match exactly one of them.
  ///   - not: A schema that the value must not match.
  ///   - if: A schema to use for control flow.
  ///   - then: A schema to match against if a value successfully matches against ``Object/if``.
  ///   - else: A schema to match against if a value fails to match against ``Object/if``.
  ///   - format: A string containing information for validating values not confined with the JSON Schema specification.
  public static func object(
    title: String? = nil,
    description: String? = nil,
    type: ValueType?,
    `default`: Value? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    examples: [Value]? = nil,
    `enum`: [Value]? = nil,
    const: Value? = nil,
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
    case .boolean(let bool):
      try container.encode(bool)
    case .object(let object):
      if let nestedUnionTypes = object.nestedUnionTypes {
        throw EncodingError.invalidValue(
          object,
          EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Nested union types are not supported. Found: \(nestedUnionTypes)."
          )
        )
      } else {
        try container.encode(SerializeableObject(object: object))
      }
    }
  }
}

extension JSONSchema.Object {
  fileprivate var nestedUnionTypes: [JSONSchema.ValueType]? {
    switch self.type {
    case .union(let types):
      var unionedTypes: [JSONSchema.ValueType]?
      for type in types {
        guard case .union(let nestedTypes) = type else { continue }
        unionedTypes = nestedTypes
      }
      return unionedTypes
    default:
      return nil
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
  var examples: [JSONSchema.Value]?

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

  var multipleOf: Numeric?
  var minimum: Numeric?
  var exclusiveMinimum: Numeric?
  var maximum: Numeric?
  var exclusiveMaximum: Numeric?

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
      self.multipleOf = number.multipleOf.map(Numeric.decimal)
      self.minimum = number.minimum.map(Numeric.decimal)
      self.exclusiveMinimum = number.exclusiveMinimum.map(Numeric.decimal)
      self.maximum = number.maximum.map(Numeric.decimal)
      self.exclusiveMaximum = number.exclusiveMaximum.map(Numeric.decimal)

    case .integer(let integer):
      if !isUnion {
        self.type = .integer
      }
      self.multipleOf = integer.multipleOf.map(Numeric.integer)
      self.minimum = integer.minimum.map(Numeric.integer)
      self.exclusiveMinimum = integer.exclusiveMinimum.map(Numeric.integer)
      self.maximum = integer.maximum.map(Numeric.integer)
      self.exclusiveMaximum = integer.exclusiveMaximum.map(Numeric.integer)

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
  enum Numeric: Codable {
    case integer(Int)
    case decimal(Decimal)

    var decimalValue: Decimal? {
      switch self {
      case .integer: nil
      case .decimal(let decimal): decimal
      }
    }

    var integerValue: Int? {
      switch self {
      case .integer(let integer): integer
      case .decimal: nil
      }
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .integer(let integer): try container.encode(integer)
      case .decimal(let decimal): try container.encode(decimal)
      }
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let integer = try? container.decode(Int.self) {
        self = .integer(integer)
      } else if let decimal = try? container.decode(Decimal.self) {
        self = .decimal(decimal)
      } else {
        throw DecodingError.typeMismatch(
          Numeric.self,
          .init(codingPath: decoder.codingPath, debugDescription: "Expected Numeric")
        )
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
    case .integer: .integer
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
    case .integer:
      self = .integer(
        multipleOf: serializeable.multipleOf?.integerValue,
        minimum: serializeable.minimum?.integerValue,
        exclusiveMinimum: serializeable.exclusiveMinimum?.integerValue,
        maximum: serializeable.maximum?.integerValue,
        exclusiveMaximum: serializeable.exclusiveMaximum?.integerValue
      )
    case .number:
      self = .number(
        multipleOf: serializeable.multipleOf?.decimalValue,
        minimum: serializeable.minimum?.decimalValue,
        exclusiveMinimum: serializeable.exclusiveMinimum?.decimalValue,
        maximum: serializeable.maximum?.decimalValue,
        exclusiveMaximum: serializeable.exclusiveMaximum?.decimalValue
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
