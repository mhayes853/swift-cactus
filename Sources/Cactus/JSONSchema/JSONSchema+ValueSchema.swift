// MARK: - ValueSchema

extension JSONSchema {
  /// The type of value represented by a ``JSONSchema``.
  public struct ValueSchema: Hashable, Sendable, Codable {
    /// A string type.
    public var string: String?

    /// Whether or not the type indicates that the value can be a boolean.
    public var isBoolean: Bool

    /// An array type.
    public var array: Array?

    /// An object type.
    public var object: Object?

    /// A number type.
    ///
    /// If this value is present with ``integer``, then the properties from `number` will override
    /// the integer properties.
    public var number: Number?

    /// An integer type.
    ///
    /// If this value is present with ``number``, then the properties from `number` will override
    /// the integer properties.
    public var integer: Integer?

    /// Whether or not the type is nullable.
    public var isNullable: Bool

    /// A union type.
    ///
    /// - Parameters:
    ///   - string: A string type.
    ///   - isBoolean: Whether or not the type indicates that the value can be a boolean.
    ///   - array: An array type.
    ///   - object: An object type.
    ///   - number: A number type.
    ///   - integer: An integer type.
    ///   - isNullable: Whether or not the type is nullable.
    public static func union(
      string: String? = nil,
      isBoolean: Bool = false,
      array: Array? = nil,
      object: Object? = nil,
      number: Number? = nil,
      integer: Integer? = nil,
      isNullable: Bool = false
    ) -> Self {
      Self(
        string: string,
        isBoolean: isBoolean,
        array: array,
        object: object,
        number: number,
        integer: integer,
        isNullable: isNullable
      )
    }

    /// A nullable type.
    public static let null = Self.union(isNullable: true)

    /// A boolean type.
    public static let boolean = Self.union(isBoolean: true)
  }
}

// MARK: - ValueTypes

extension JSONSchema.ValueSchema {
  /// All of the ``JSONSchema/ValueType`` instances that this value schema represents.
  public var valueTypes: [JSONSchema.ValueType] {
    var schemaTypes = [JSONSchema.ValueType]()
    if self.array != nil {
      schemaTypes.append(.array)
    }
    if self.integer != nil {
      schemaTypes.append(.integer)
    }
    if self.number != nil {
      schemaTypes.append(.number)
    }
    if self.string != nil {
      schemaTypes.append(.string)
    }
    if self.object != nil {
      schemaTypes.append(.object)
    }
    if self.isBoolean {
      schemaTypes.append(.boolean)
    }
    if self.isNullable {
      schemaTypes.append(.null)
    }
    return schemaTypes
  }
}

// MARK: - String

extension JSONSchema.ValueSchema {
  /// A string-specific schema.
  public struct String: Hashable, Sendable, Codable {
    /// The minimum length of the string.
    ///
    /// [6.3.2](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.3.2)
    public var minLength: Int?

    /// The maximum length of the string.
    ///
    /// [6.3.1](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.3.1)
    public var maxLength: Int?

    /// A regular expression that the string must match.
    ///
    /// [6.3.3](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.3.3)
    public var pattern: Swift.String?

    /// Creates a string-specific schema.
    ///
    /// - Parameters:
    ///   - minLength: The minimum length of the string.
    ///   - maxLength: The maximum length of the string.
    ///   - pattern: A regular expression that the string must match.
    public static func string(
      minLength: Int? = nil,
      maxLength: Int? = nil,
      pattern: Swift.String? = nil
    ) -> Self {
      Self(minLength: minLength, maxLength: maxLength, pattern: pattern)
    }
  }

  /// Creates a string-specific schema.
  ///
  /// - Parameters:
  ///   - minLength: The minimum length of the string.
  ///   - maxLength: The maximum length of the string.
  ///   - pattern: A regular expression that the string must match.
  public static func string(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: Swift.String? = nil
  ) -> Self {
    .union(string: .string(minLength: minLength, maxLength: maxLength, pattern: pattern))
  }
}

// MARK: - Number

extension JSONSchema.ValueSchema {
  /// A number-specific schema.
  public struct Number: Hashable, Sendable, Codable {
    /// The value that the number must be a multiple of.
    ///
    /// [6.2.1](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.1)
    public var multipleOf: Double?

    /// The minimum value (inclusive) of the number.
    ///
    /// [6.2.4](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.4)
    public var minimum: Double?

    /// The minimum value (exclusive) of the number.
    ///
    /// [6.2.5](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.5)
    public var exclusiveMinimum: Double?

    /// The maximum value (inclusive) of the number.
    ///
    /// [6.2.2](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.2)
    public var maximum: Double?

    /// The maximum value (exclusive) of the number.
    ///
    /// [6.2.3](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.3)
    public var exclusiveMaximum: Double?

    /// Creates a number-specific schema.
    ///
    /// - Parameters:
    ///   - multipleOf: The value that the number must be a multiple of.
    ///   - minimum: The minimum value (inclusive) of the number.
    ///   - exclusiveMinimum: The minimum value (exclusive) of the number.
    ///   - maximum: The maximum value (inclusive) of the number.
    ///   - exclusiveMaximum: The maximum value (exclusive) of the number.
    public static func number(
      multipleOf: Double? = nil,
      minimum: Double? = nil,
      exclusiveMinimum: Double? = nil,
      maximum: Double? = nil,
      exclusiveMaximum: Double? = nil
    ) -> Self {
      Self(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      )
    }
  }

  /// Creates a number-specific schema.
  ///
  /// - Parameters:
  ///   - multipleOf: The value that the number must be a multiple of.
  ///   - minimum: The minimum value (inclusive) of the number.
  ///   - exclusiveMinimum: The minimum value (exclusive) of the number.
  ///   - maximum: The maximum value (inclusive) of the number.
  ///   - exclusiveMaximum: The maximum value (exclusive) of the number.
  public static func number(
    multipleOf: Double? = nil,
    minimum: Double? = nil,
    exclusiveMinimum: Double? = nil,
    maximum: Double? = nil,
    exclusiveMaximum: Double? = nil
  ) -> Self {
    .union(
      number: .number(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      )
    )
  }
}

// MARK: - Integer

extension JSONSchema.ValueSchema {
  /// An integer-specific schema.
  public struct Integer: Hashable, Sendable, Codable {
    /// The value that the integer must be a multiple of.
    ///
    /// [6.2.1](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.1)
    public var multipleOf: Int?

    /// The minimum value (inclusive) of the integer.
    ///
    /// [6.2.4](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.4)
    public var minimum: Int?

    /// The minimum value (exclusive) of the integer.
    ///
    /// [6.2.5](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.5)
    public var exclusiveMinimum: Int?

    /// The maximum value (inclusive) of the integer.
    ///
    /// [6.2.2](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.2)
    public var maximum: Int?

    /// The maximum value (exclusive) of the integer.
    ///
    /// [6.2.3](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.2.3)
    public var exclusiveMaximum: Int?

    /// Creates a number-specific schema.
    ///
    /// - Parameters:
    ///   - multipleOf: The value that the integer must be a multiple of.
    ///   - minimum: The minimum value (inclusive) of the integer.
    ///   - exclusiveMinimum: The minimum value (exclusive) of the integer.
    ///   - maximum: The maximum value (inclusive) of the integer.
    ///   - exclusiveMaximum: The maximum value (exclusive) of the integer.
    public static func integer(
      multipleOf: Int? = nil,
      minimum: Int? = nil,
      exclusiveMinimum: Int? = nil,
      maximum: Int? = nil,
      exclusiveMaximum: Int? = nil
    ) -> Self {
      Self(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      )
    }
  }

  /// Creates an integer-specific schema.
  ///
  /// - Parameters:
  ///   - multipleOf: The value that the integer must be a multiple of.
  ///   - minimum: The minimum value (inclusive) of the integer.
  ///   - exclusiveMinimum: The minimum value (exclusive) of the integer.
  ///   - maximum: The maximum value (inclusive) of the integer.
  ///   - exclusiveMaximum: The maximum value (exclusive) of the integer.
  public static func integer(
    multipleOf: Int? = nil,
    minimum: Int? = nil,
    exclusiveMinimum: Int? = nil,
    maximum: Int? = nil,
    exclusiveMaximum: Int? = nil
  ) -> Self {
    .union(
      integer: .integer(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      )
    )
  }
}

// MARK: - Array

extension JSONSchema.ValueSchema {
  /// An array-specific schema.
  public struct Array: Hashable, Sendable, Codable {
    /// A method of defining items in an array-specific schema.
    public enum Items: Hashable, Sendable, Codable {
      /// The ``JSONSchema`` that all items in the array must conform to.
      case schemaForAll(JSONSchema)

      /// Individual ``JSONSchema`` instances for each item in the array.
      case itemsSchemas([JSONSchema])

      public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .schemaForAll(let schema): try container.encode(schema)
        case .itemsSchemas(let schemas): try container.encode(schemas)
        }
      }

      public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let schema = try? container.decode(JSONSchema.self) {
          self = .schemaForAll(schema)
        } else if let schemas = try? container.decode([JSONSchema].self) {
          self = .itemsSchemas(schemas)
        } else {
          throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid array items schema"
          )
        }
      }
    }

    /// The schema for the items in the array.
    ///
    /// [6.4.1](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.1)
    public var items: Items?

    /// A schema describing elements that are not covered by `items`.
    ///
    /// [6.4.2](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.2)
    public var additionalItems: JSONSchema?

    /// The minimum number of items allowed in the array.
    ///
    /// [6.4.4](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.4)
    public var minItems: Int?

    /// The maximum number of items allowed in the array.
    ///
    /// [6.4.3](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.3)
    public var maxItems: Int?

    /// A boolean that indicates whether all items in the array must be unique.
    ///
    /// [6.4.5](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.5)
    public var uniqueItems: Bool?

    /// A schema that must be contained within the array.
    ///
    /// [6.4.6](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01#section-6.4.6)
    public var contains: JSONSchema?

    /// Creates an array-specific schema.
    ///
    /// - Parameters:
    ///   - items: The schema for the items in the array.
    ///   - additionalItems: The schema for additional items in the array.
    ///   - minItems: The minimum number of items allowed in the array.
    ///   - maxItems: The maximum number of items allowed in the array.
    ///   - uniqueItems: A boolean that indicates whether all items in the array must be unique.
    ///   - contains: A schema that must be contained within the array.
    public static func array(
      items: Items? = nil,
      additionalItems: JSONSchema? = nil,
      minItems: Int? = nil,
      maxItems: Int? = nil,
      uniqueItems: Bool? = nil,
      contains: JSONSchema? = nil
    ) -> Self {
      Self(
        items: items,
        additionalItems: additionalItems,
        minItems: minItems,
        maxItems: maxItems,
        uniqueItems: uniqueItems,
        contains: contains
      )
    }
  }

  /// Creates an array-specific schema.
  ///
  /// - Parameters:
  ///   - items: The schema for the items in the array.
  ///   - additionalItems: The schema for additional items in the array.
  ///   - minItems: The minimum number of items allowed in the array.
  ///   - maxItems: The maximum number of items allowed in the array.
  ///   - uniqueItems: A boolean that indicates whether all items in the array must be unique.
  ///   - contains: A schema that must be contained within the array.
  public static func array(
    items: Array.Items? = nil,
    additionalItems: JSONSchema? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil,
    contains: JSONSchema? = nil
  ) -> Self {
    .union(
      array: .array(
        items: items,
        additionalItems: additionalItems,
        minItems: minItems,
        maxItems: maxItems,
        uniqueItems: uniqueItems,
        contains: contains
      )
    )
  }
}

// MARK: - Object

extension JSONSchema.ValueSchema {
  /// An object-specific schema.
  ///
  /// [6.5](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5)
  public struct Object: Hashable, Sendable, Codable {
    /// A dictionary of property names and their corresponding schemas.
    ///
    /// [6.5.4](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.4)
    public var properties: [Swift.String: JSONSchema]?

    /// An array of property names that are required for the object.
    ///
    /// [6.5.3](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.3)
    public var required: [Swift.String]?

    /// The minimum number of properties the object must have.
    ///
    /// [6.5.2](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.2)
    public var minProperties: Int?

    /// The maximum number of properties the object can have.
    ///
    /// [6.5.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.1)
    public var maxProperties: Int?

    /// A schema that defines constraints for additional properties not defined on the object.
    ///
    /// [6.5.6](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.6)
    public var additionalProperties: JSONSchema?

    /// A dictionary of regex patterns and their corresponding schemas for matching property names.
    ///
    /// [6.5.5](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.5)
    public var patternProperties: [Swift.String: JSONSchema]?

    /// A schema that defines constraints for property names.
    ///
    /// [6.5.8](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.5.8)
    public var propertyNames: JSONSchema?

    /// Creates an object-specific schema.
    ///
    /// - Parameters:
    ///   - properties: A dictionary of property names and their corresponding schemas.
    ///   - required: An array of required property names.
    ///   - minProperties: The minimum number of properties required.
    ///   - maxProperties: The maximum number of properties allowed.
    ///   - additionalProperties: A schema that defines constraints for additional properties not defined on the object.
    ///   - patternProperties: A dictionary of regex patterns and their corresponding schemas for matching property names.
    ///   - propertyNames: A schema that defines constraints for property names.
    public static func object(
      properties: [Swift.String: JSONSchema]? = nil,
      required: [Swift.String]? = nil,
      minProperties: Int? = nil,
      maxProperties: Int? = nil,
      additionalProperties: JSONSchema? = nil,
      patternProperties: [Swift.String: JSONSchema]? = nil,
      propertyNames: JSONSchema? = nil
    ) -> Self {
      Self(
        properties: properties,
        required: required,
        minProperties: minProperties,
        maxProperties: maxProperties,
        additionalProperties: additionalProperties,
        patternProperties: patternProperties,
        propertyNames: propertyNames
      )
    }
  }

  /// Creates an object-specific schema.
  ///
  /// - Parameters:
  ///   - properties: A dictionary of property names and their corresponding schemas.
  ///   - required: An array of required property names.
  ///   - minProperties: The minimum number of properties required.
  ///   - maxProperties: The maximum number of properties allowed.
  ///   - additionalProperties: A schema that defines constraints for additional properties not defined on the object.
  ///   - patternProperties: A dictionary of regex patterns and their corresponding schemas for matching property names.
  ///   - propertyNames: A schema that defines constraints for property names.
  public static func object(
    properties: [Swift.String: JSONSchema]? = nil,
    required: [Swift.String]? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    additionalProperties: JSONSchema? = nil,
    patternProperties: [Swift.String: JSONSchema]? = nil,
    propertyNames: JSONSchema? = nil
  ) -> Self {
    .union(
      object: .object(
        properties: properties,
        required: required,
        minProperties: minProperties,
        maxProperties: maxProperties,
        additionalProperties: additionalProperties,
        patternProperties: patternProperties,
        propertyNames: propertyNames
      )
    )
  }
}
