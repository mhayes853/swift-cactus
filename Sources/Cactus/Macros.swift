// MARK: - Macros

/// Generates ``JSONGenerable`` and stream-parseable support for a struct.
@attached(extension, conformances: JSONGenerable, StreamParseable, names: named(Partial))
@attached(member, names: named(streamPartialValue), named(jsonSchema))
public macro JSONGenerable() = #externalMacro(module: "CactusMacros", type: "JSONGenerableMacro")

/// Marks a stored property as ignored for ``JSONGenerable`` schema and partial synthesis.
@attached(peer)
public macro JSONGenerableIgnored() =
  #externalMacro(module: "CactusMacros", type: "JSONGenerableIgnoredMacro")
