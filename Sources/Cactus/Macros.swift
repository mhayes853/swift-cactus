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
