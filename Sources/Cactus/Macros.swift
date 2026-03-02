import CactusCore

// MARK: - Macros

/// Generates ``JSONSchemaRepresentable`` support for a struct.
///
/// Example:
/// ```swift
/// @JSONSchema(title: "Recipe", description: "Recipe payload")
/// struct Recipe: Codable {
///   @JSONSchemaProperty(.string(minLength: 1), description: "Recipe title")
///   var title: String
///   @JSONSchemaProperty(.integer(minimum: 1))
///   var servings: Int
/// }
/// ```
@attached(extension, conformances: JSONSchemaRepresentable)
@attached(member, names: named(jsonSchema))
@attached(memberAttribute)
public macro JSONSchema(
  title: String? = nil,
  description: String? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONSchemaMacro")

/// Marks a stored property as ignored for ``JSONSchema`` schema synthesis.
///
/// Example:
/// ```swift
/// @JSONSchema
/// struct Recipe: Codable {
///   var title: String
///   @JSONSchemaIgnored
///   var internalID: String
/// }
/// ```
@attached(peer)
public macro JSONSchemaIgnored() =
  #externalMacro(module: "CactusMacros", type: "JSONSchemaIgnoredMacro")

/// Overrides schema synthesis for a stored property.
///
/// Example:
/// ```swift
/// @JSONSchema
/// struct Recipe: Codable {
///   @JSONSchemaProperty(.string(minLength: 1), key: "recipe_title", description: "Display title")
///   var title: String
///
///   @JSONSchemaProperty(.array(items: .schemaForAll(.string(minLength: 1)), minItems: 1))
///   var tags: [String]
/// }
/// ```
@attached(peer)
public macro JSONSchemaProperty(
  _ schema: _JSONSchemaPropertySchema = .inferred,
  key: Swift.String? = nil,
  description: String? = nil
) = #externalMacro(module: "CactusMacros", type: "JSONSchemaPropertyMacro")

public struct _JSONSchemaPropertySchema {
  public static var inferred: Self { Self() }

  public static func string(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil
  ) -> Self { Self() }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public static func string<Output>(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: Regex<Output>? = nil
  ) -> Self { Self() }

  public static func number(
    multipleOf: Double? = nil,
    minimum: Double? = nil,
    exclusiveMinimum: Double? = nil,
    maximum: Double? = nil,
    exclusiveMaximum: Double? = nil
  ) -> Self { Self() }

  public static func integer(
    multipleOf: Int? = nil,
    minimum: Int? = nil,
    exclusiveMinimum: Int? = nil,
    maximum: Int? = nil,
    exclusiveMaximum: Int? = nil
  ) -> Self { Self() }

  public static var boolean: Self { Self() }

  public static func object(
    properties: [Swift.String: JSONSchema]? = nil,
    required: [Swift.String]? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    additionalProperties: JSONSchema? = nil,
    patternProperties: [Swift.String: JSONSchema]? = nil,
    propertyNames: JSONSchema? = nil
  ) -> Self { Self() }

  public static func array(
    items: JSONSchema.ValueSchema.Array.Items? = nil,
    additionalItems: JSONSchema? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil,
    contains: JSONSchema? = nil
  ) -> Self { Self() }

  public static func custom(_ schema: JSONSchema) -> Self { Self() }
}

public func _cactusMergeJSONSchema(
  _ schema: JSONSchema,
  title: String? = nil,
  description: String? = nil
) -> JSONSchema {
  guard case .object(var object) = schema else { return schema }
  if let title {
    object.title = title
  }
  if let description {
    object.description = description
  }
  return .object(object)
}
