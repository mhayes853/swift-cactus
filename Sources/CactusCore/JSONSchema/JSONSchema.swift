// MARK: - JSONSchema

/// An enun defining a JSON Schema.
///
/// A valid json schema is either an object or a boolean.
///
/// ```swift
/// @JSONSchema
/// struct MyValue: Codable {
///   @JSONSchemaProperty(.string(pattern: /[0-9A-Za-z]+/))
///   var property: String
///
///   @JSONSchemaProperty(.integer(minimum: 10))
///   var num: Int
/// }
///
/// let jsonValue = JSONSchema.Value.object([
///   "property": "this is a string",
///   "num": 10
/// ])
///
/// // Validation
///
/// try JSONSchema.Validator.shared.validate(
///   value: jsonValue,
///   with: MyValue.jsonSchema
/// )
///
/// // Codable Support
///
/// let decoded = try JSONSchema.Value.Decoder()
///   .decode(MyValue.self, from: jsonValue)
///
/// let encoded: JSONSchema.Value = try JSONSchema.Value.Encoder()
///   .encode(MyValue(property: "blob", num: 20))
/// ```
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

    /// The ``JSONSchema/ValueSchema`` of this schema.
    public var valueSchema: ValueSchema?

    /// The ``JSONSchema/ValueType`` of this schema.
    ///
    /// [6.1.1](https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-6.1.1)
    public var type: ValueType? {
      self.valueSchema?.type
    }

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
    ///   - valueSchema: The ``JSONSchema/ValueSchema`` of this schema.
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
      valueSchema: ValueSchema?,
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
      self.valueSchema = valueSchema
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
  ///   - valueSchema: The ``JSONSchema/ValueSchema`` of this schema.
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
    valueSchema: ValueSchema?,
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
        valueSchema: valueSchema,
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

  private static func typed(
    title: String? = nil,
    description: String? = nil,
    valueSchema: ValueSchema,
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
      title: title,
      description: description,
      valueSchema: valueSchema,
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
  }

  /// Creates a string-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - minLength: The minimum length of the string.
  ///   - maxLength: The maximum length of the string.
  ///   - pattern: A regular expression that the string must match.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func string(
    title: String? = nil,
    description: String? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .string(minLength: minLength, maxLength: maxLength, pattern: pattern),
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
  }

  /// Creates a number-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - multipleOf: The value that the number must be a multiple of.
  ///   - minimum: The minimum value (inclusive) of the number.
  ///   - exclusiveMinimum: The minimum value (exclusive) of the number.
  ///   - maximum: The maximum value (inclusive) of the number.
  ///   - exclusiveMaximum: The maximum value (exclusive) of the number.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func number(
    title: String? = nil,
    description: String? = nil,
    multipleOf: Double? = nil,
    minimum: Double? = nil,
    exclusiveMinimum: Double? = nil,
    maximum: Double? = nil,
    exclusiveMaximum: Double? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .number(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      ),
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
  }

  /// Creates an integer-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - multipleOf: The value that the integer must be a multiple of.
  ///   - minimum: The minimum value (inclusive) of the integer.
  ///   - exclusiveMinimum: The minimum value (exclusive) of the integer.
  ///   - maximum: The maximum value (inclusive) of the integer.
  ///   - exclusiveMaximum: The maximum value (exclusive) of the integer.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func integer(
    title: String? = nil,
    description: String? = nil,
    multipleOf: Int? = nil,
    minimum: Int? = nil,
    exclusiveMinimum: Int? = nil,
    maximum: Int? = nil,
    exclusiveMaximum: Int? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .integer(
        multipleOf: multipleOf,
        minimum: minimum,
        exclusiveMinimum: exclusiveMinimum,
        maximum: maximum,
        exclusiveMaximum: exclusiveMaximum
      ),
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
  }

  /// Creates an array-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - items: The schema for the items in the array.
  ///   - additionalItems: A schema describing elements not covered by `items`.
  ///   - minItems: The minimum number of items allowed in the array.
  ///   - maxItems: The maximum number of items allowed in the array.
  ///   - uniqueItems: A boolean that indicates whether all items in the array must be unique.
  ///   - contains: A schema that must be contained within the array.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func array(
    title: String? = nil,
    description: String? = nil,
    items: ValueSchema.Array.Items? = nil,
    additionalItems: JSONSchema? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil,
    contains: JSONSchema? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .array(
        items: items,
        additionalItems: additionalItems,
        minItems: minItems,
        maxItems: maxItems,
        uniqueItems: uniqueItems,
        contains: contains
      ),
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
  }

  /// Creates an object-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - properties: A dictionary of property names and their corresponding schemas.
  ///   - required: An array of required property names.
  ///   - minProperties: The minimum number of properties the object must have.
  ///   - maxProperties: The maximum number of properties the object can have.
  ///   - additionalProperties: A schema that defines constraints for additional properties not defined on the object.
  ///   - patternProperties: A dictionary of regex patterns and corresponding schemas for matching property names.
  ///   - propertyNames: A schema that defines constraints for property names.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
    properties: [String: JSONSchema]? = nil,
    required: [String]? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    additionalProperties: JSONSchema? = nil,
    patternProperties: [String: JSONSchema]? = nil,
    propertyNames: JSONSchema? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .object(
        properties: properties,
        required: required,
        minProperties: minProperties,
        maxProperties: maxProperties,
        additionalProperties: additionalProperties,
        patternProperties: patternProperties,
        propertyNames: propertyNames
      ),
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
  }

  /// Creates a null-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func null(
    title: String? = nil,
    description: String? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .null,
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
  }

  /// Creates a boolean-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func bool(
    title: String? = nil,
    description: String? = nil,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .boolean,
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
  }

  /// Creates a union-specific object schema.
  ///
  /// - Parameters:
  ///   - title: The title of the schema.
  ///   - description: The description of the schema.
  ///   - string: String-specific constraints included in the union.
  ///   - bool: Whether the union includes the boolean type.
  ///   - number: Number-specific constraints included in the union.
  ///   - integer: Integer-specific constraints included in the union.
  ///   - array: Array-specific constraints included in the union.
  ///   - object: Object-specific constraints included in the union.
  ///   - null: Whether the union includes the null type.
  ///   - default: The default value of the schema.
  ///   - readOnly: Indicates whether the value is managed exclusively by the owning authority.
  ///   - writeOnly: Indicates whether the value is present when retrieved from the owning authority.
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
  public static func union(
    title: String? = nil,
    description: String? = nil,
    string: ValueSchema.String? = nil,
    bool: Bool = false,
    number: ValueSchema.Number? = nil,
    integer: ValueSchema.Integer? = nil,
    array: ValueSchema.Array? = nil,
    object: ValueSchema.Object? = nil,
    null: Bool = false,
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
    .typed(
      title: title,
      description: description,
      valueSchema: .union(
        string: string,
        isBoolean: bool,
        array: array,
        object: object,
        number: number,
        integer: integer,
        isNullable: null
      ),
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
  }
}

// MARK: - ExpressibleByBooleanLiteral

extension JSONSchema: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .boolean(value)
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
      try container.encode(SerializeableObject(object: object))
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
  var type: JSONSchema.ValueType?
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

  var items: JSONSchema.ValueSchema.Array.Items?
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

    if let array = object.valueSchema?.array {
      self.items = array.items
      self.additionalItems = array.additionalItems
      self.minItems = array.minItems
      self.maxItems = array.maxItems
      self.uniqueItems = array.uniqueItems
      self.contains = array.contains
    }

    if let integer = object.valueSchema?.integer {
      self.multipleOf = integer.multipleOf.map(Numeric.integer)
      self.minimum = integer.minimum.map(Numeric.integer)
      self.exclusiveMinimum = integer.exclusiveMinimum.map(Numeric.integer)
      self.maximum = integer.maximum.map(Numeric.integer)
      self.exclusiveMaximum = integer.exclusiveMaximum.map(Numeric.integer)
    }

    if let number = object.valueSchema?.number {
      self.multipleOf = number.multipleOf.map(Numeric.double)
      self.minimum = number.minimum.map(Numeric.double)
      self.exclusiveMinimum = number.exclusiveMinimum.map(Numeric.double)
      self.maximum = number.maximum.map(Numeric.double)
      self.exclusiveMaximum = number.exclusiveMaximum.map(Numeric.double)
    }

    if let string = object.valueSchema?.string {
      self.minLength = string.minLength
      self.maxLength = string.maxLength
      self.pattern = string.pattern
    }

    if let object = object.valueSchema?.object {
      self.properties = object.properties
      self.patternProperties = object.patternProperties
      self.additionalProperties = object.additionalProperties
      self.minProperties = object.minProperties
      self.maxProperties = object.maxProperties
      self.required = object.required
    }

    self.type = object.type
  }
}

extension SerializeableObject {
  enum Numeric: Codable {
    case integer(Int)
    case double(Double)

    var doubleValue: Double {
      switch self {
      case .integer(let integer): Double(integer)
      case .double(let decimal): decimal
      }
    }

    var integerValue: Int {
      switch self {
      case .integer(let integer): integer
      case .double(let decimal): Int(decimal)
      }
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .integer(let integer): try container.encode(integer)
      case .double(let decimal): try container.encode(decimal)
      }
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let integer = try? container.decode(Int.self) {
        self = .integer(integer)
      } else if let double = try? container.decode(Double.self) {
        self = .double(double)
      } else {
        throw DecodingError.typeMismatch(
          Numeric.self,
          .init(codingPath: decoder.codingPath, debugDescription: "Expected Numeric")
        )
      }
    }
  }
}

extension JSONSchema.Object {
  fileprivate init(serializeable: SerializeableObject) {
    self.init(
      title: serializeable.title,
      description: serializeable.description,
      valueSchema: JSONSchema.ValueSchema(serializeable: serializeable),
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

extension JSONSchema.ValueSchema {
  fileprivate init?(serializeable: SerializeableObject) {
    guard let type = serializeable.type else { return nil }

    self = .union()
    if type.contains(.array) {
      self.array = .array(
        items: serializeable.items,
        additionalItems: serializeable.additionalItems,
        minItems: serializeable.minItems,
        maxItems: serializeable.maxItems,
        uniqueItems: serializeable.uniqueItems,
        contains: serializeable.contains
      )
    }
    if type.contains(.integer) {
      self.integer = .integer(
        multipleOf: serializeable.multipleOf?.integerValue,
        minimum: serializeable.minimum?.integerValue,
        exclusiveMinimum: serializeable.exclusiveMinimum?.integerValue,
        maximum: serializeable.maximum?.integerValue,
        exclusiveMaximum: serializeable.exclusiveMaximum?.integerValue
      )
    }
    if type.contains(.number) {
      self.number = .number(
        multipleOf: serializeable.multipleOf?.doubleValue,
        minimum: serializeable.minimum?.doubleValue,
        exclusiveMinimum: serializeable.exclusiveMinimum?.doubleValue,
        maximum: serializeable.maximum?.doubleValue,
        exclusiveMaximum: serializeable.exclusiveMaximum?.doubleValue
      )
    }
    if type.contains(.string) {
      self.string = .string(
        minLength: serializeable.minLength,
        maxLength: serializeable.maxLength,
        pattern: serializeable.pattern
      )
    }
    if type.contains(.object) {
      self.object = .object(
        properties: serializeable.properties,
        required: serializeable.required,
        minProperties: serializeable.minProperties,
        maxProperties: serializeable.maxProperties,
        additionalProperties: serializeable.additionalItems,
        patternProperties: serializeable.patternProperties,
        propertyNames: serializeable.propertyNames
      )
    }
    if type.contains(.null) {
      self.isNullable = true
    }
    if type.contains(.boolean) {
      self.isBoolean = true
    }
  }
}

extension JSONSchema.ValueType {
  fileprivate var containedTypes: [Self] {
    let allTypes = [Self.integer, .string, .boolean, .array, .object, .number, .null]
    return allTypes.filter { self.contains($0) }
  }
}
