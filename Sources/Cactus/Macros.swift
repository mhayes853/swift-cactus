import CactusCore

// MARK: - Macros

/// Generates ``JSONSchemaRepresentable`` support for a struct.
@attached(extension, conformances: JSONSchemaRepresentable)
@attached(member, names: named(jsonSchema))
public macro JSONSchema() = #externalMacro(module: "CactusMacros", type: "JSONSchemaMacro")

/// Marks a stored property as ignored for ``JSONSchema`` schema synthesis.
@attached(peer)
public macro JSONSchemaIgnored() =
  #externalMacro(module: "CactusMacros", type: "JSONSchemaIgnoredMacro")

/// Overrides schema synthesis for a string property using semantic validation constraints.
@attached(peer)
public macro JSONStringSchema(
  minLength: Int? = nil,
  maxLength: Int? = nil,
  pattern: String? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONStringSchemaMacro")

/// Overrides schema synthesis for a number property using semantic validation constraints.
@attached(peer)
public macro JSONNumberSchema(
  multipleOf: Double? = nil,
  minimum: Double? = nil,
  exclusiveMinimum: Double? = nil,
  maximum: Double? = nil,
  exclusiveMaximum: Double? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONNumberSchemaMacro")

/// Overrides schema synthesis for an integer property using semantic validation constraints.
@attached(peer)
public macro JSONIntegerSchema(
  multipleOf: Int? = nil,
  minimum: Int? = nil,
  exclusiveMinimum: Int? = nil,
  maximum: Int? = nil,
  exclusiveMaximum: Int? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONIntegerSchemaMacro")

/// Overrides schema synthesis for a boolean property.
@attached(peer)
public macro JSONBooleanSchema() =
  #externalMacro(module: "CactusMacros", type: "JSONBooleanSchemaMacro")

/// Overrides schema synthesis for an array property using semantic validation constraints.
@attached(peer)
public macro JSONArraySchema(
  items: JSONSchema.ValueSchema.Array.Items? = nil,
  additionalItems: JSONSchema? = nil,
  minItems: Int? = nil,
  maxItems: Int? = nil,
  uniqueItems: Bool? = nil,
  contains: JSONSchema? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONArraySchemaMacro")
