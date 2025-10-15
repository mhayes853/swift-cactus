// MARK: - ValueType

extension JSONSchema {
  /// The type of value represented by a ``JSONSchema``.
  public enum ValueType: Hashable, Sendable, Codable {
    /// A string type.
    case string(String)

    /// A boolean type.
    case boolean

    /// An array type.
    case array(Array)

    /// An object type.
    case object(Object)

    /// A number type.
    case number(Number)

    /// A null type.
    case null

    /// A union type.
    case union([Self])
  }
}

// MARK: - ExpressibleByArrayLiteral

extension JSONSchema.ValueType: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Self...) {
    self = .union(elements)
  }
}

// MARK: - String

extension JSONSchema.ValueType {
  /// A string-specific schema.
  public struct String: Hashable, Sendable, Codable {
    /// The minimum length of the string.
    ///
    /// [6.3.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.3.2)
    public let minLength: Int?

    /// The maximum length of the string.
    ///
    /// [6.3.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.3.1)
    public let maxLength: Int?

    /// A regular expression that the string must match.
    ///
    /// [6.3.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.3.3)
    public let pattern: Swift.String?

    /// Creates a string-specific schema.
    ///
    /// - Parameters:
    ///   - minLength: The minimum length of the string.
    ///   - maxLength: The maximum length of the string.
    ///   - pattern: A regular expression that the string must match.
    public init(minLength: Int? = nil, maxLength: Int? = nil, pattern: Swift.String? = nil) {
      self.minLength = minLength
      self.maxLength = maxLength
      self.pattern = pattern
    }
  }
}

// MARK: - Number

extension JSONSchema.ValueType {
  /// A number-specific schema.
  public struct Number: Hashable, Sendable, Codable {
    /// The value that the number must be a multiple of.
    ///
    /// [6.2.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.2.1)
    public var multipleOf: Double?

    /// The minimum value (inclusive) of the number.
    ///
    /// [6.2.4](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.2.4)
    public var minimum: Double?

    /// The minimum value (exclusive) of the number.
    ///
    /// [6.2.5](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.2.5)
    public var exclusiveMinimum: Double?

    /// The maximum value (inclusive) of the number.
    ///
    /// [6.2.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.2.2)
    public var maximum: Double?

    /// The maximum value (exclusive) of the number.
    ///
    /// [6.2.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.2.3)
    public var exclusiveMaximum: Double?

    /// Creates a number-specific schema.
    ///
    /// - Parameters:
    ///   - multipleOf: The value that the number must be a multiple of.
    ///   - minimum: The minimum value (inclusive) of the number.
    ///   - exclusiveMinimum: The minimum value (exclusive) of the number.
    ///   - maximum: The maximum value (inclusive) of the number.
    ///   - exclusiveMaximum: The maximum value (exclusive) of the number.
    public init(
      multipleOf: Double? = nil,
      minimum: Double? = nil,
      exclusiveMinimum: Double? = nil,
      maximum: Double? = nil,
      exclusiveMaximum: Double? = nil
    ) {
      self.multipleOf = multipleOf
      self.maximum = maximum
      self.exclusiveMaximum = exclusiveMaximum
      self.minimum = minimum
      self.exclusiveMinimum = exclusiveMinimum
    }
  }
}

// MARK: - Array

extension JSONSchema.ValueType {
  /// An array-specific schema.
  public struct Array: Hashable, Sendable, Codable {
    /// The schema for the items in the array.
    ///
    /// [10.3.1.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.1.2)
    public var items: JSONSchema?

    /// An array of schemas for the first few items in the array.
    ///
    /// [10.3.1.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.1.1)
    public var prefixItems: [JSONSchema]?

    /// The minimum number of items allowed in the array.
    ///
    /// [6.4.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.4.2)
    public var minItems: Int?

    /// The maximum number of items allowed in the array.
    ///
    /// [6.4.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.4.1)
    public var maxItems: Int?

    /// A boolean that indicates whether all items in the array must be unique.
    ///
    /// [6.4.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.4.3)
    public var uniqueItems: Bool?

    /// A schema that must be contained within the array.
    ///
    /// [10.3.1.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.10.3.1.3)
    public var contains: JSONSchema?

    /// The minimum number of items that must match the schema denoted by ``contains``.
    ///
    /// [6.4.5](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.4.5)
    public var minContains: Int?

    /// The maximum number of items that must match the schema denoted by ``contains``.
    ///
    /// [6.4.4](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.4.4)
    public var maxContains: Int?

    /// Creates an array-specific schema.
    ///
    /// - Parameters:
    ///   - items: The schema for the items in the array.
    ///   - prefixItems: An array of schemas for the first few items in the array.
    ///   - minItems: The minimum number of items allowed in the array.
    ///   - maxItems: The maximum number of items allowed in the array.
    ///   - uniqueItems: A boolean that indicates whether all items in the array must be unique.
    ///   - contains: A schema that must be contained within the array.
    ///   - minContains: The minimum number of items that must match the schema denoted by ``contains``.
    ///   - maxContains: The maximum number of items that must match the schema denoted by ``contains``.
    public init(
      items: JSONSchema? = nil,
      prefixItems: [JSONSchema]? = nil,
      minItems: Int? = nil,
      maxItems: Int? = nil,
      uniqueItems: Bool? = nil,
      contains: JSONSchema? = nil,
      minContains: Int? = nil,
      maxContains: Int? = nil
    ) {
      self.items = items
      self.prefixItems = prefixItems
      self.minItems = minItems
      self.maxItems = maxItems
      self.uniqueItems = uniqueItems
      self.contains = contains
      self.minContains = minContains
      self.maxContains = maxContains
    }
  }
}

// MARK: - Object

extension JSONSchema.ValueType {
  /// An object-specific schema.
  public struct Object: Hashable, Sendable, Codable {
    /// A dictionary of property names and their corresponding schemas.
    ///
    /// [10.3.2.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.2.1)
    public var properties: [String: JSONSchema]?

    /// An array of property names that are required for the object.
    ///
    /// [6.5.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.5.3)
    public var required: [String]?

    /// The minimum number of properties the object must have.
    ///
    /// [6.5.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.5.2)
    public var minProperties: Int?

    /// The maximum number of properties the object can have.
    ///
    /// [6.5.1](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-00#rfc.section.6.5.1)
    public var maxProperties: Int?

    /// A schema that defines constraints for additional properties not defined on the object.
    ///
    /// [10.3.2.3](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.2.3)
    public var additionalProperties: JSONSchema?

    /// A dictionary of regex patterns and their corresponding schemas for matching property names.
    ///
    /// [10.3.2.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.2.2)
    public var patternProperties: [String: JSONSchema]?

    /// A schema that defines constraints for property names.
    ///
    /// [10.3.2.4](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-00#rfc.section.10.3.2.4)
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
    public init(
      properties: [JSONSchema.ValueType.String: JSONSchema]? = nil,
      required: [JSONSchema.ValueType.String]? = nil,
      minProperties: Int? = nil,
      maxProperties: Int? = nil,
      additionalProperties: JSONSchema? = nil,
      patternProperties: [JSONSchema.ValueType.String: JSONSchema]? = nil,
      propertyNames: JSONSchema? = nil
    ) {
      self.properties = properties
      self.required = required
      self.minProperties = minProperties
      self.maxProperties = maxProperties
      self.additionalProperties = additionalProperties
      self.patternProperties = patternProperties
      self.propertyNames = propertyNames
    }
  }
}
