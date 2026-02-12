import Foundation
import StreamParsing

// MARK: - JSONSchemaRepresentable

/// A type that can generate a JSON schema description of itself.
public protocol JSONSchemaRepresentable {
  /// The JSON schema describing this type.
  static var jsonSchema: JSONSchema { get }
}

/// A type that can generate a JSON schema and decode itself from a JSON value.
public typealias JSONGenerable = JSONSchemaRepresentable & Codable

extension JSONSchemaRepresentable where Self: Codable {
  /// Creates this type from a JSON schema value.
  ///
  /// - Parameters:
  ///   - jsonValue: The source JSON value.
  ///   - validator: A validator used to validate `jsonValue` against ``jsonSchema``.
  ///   - decoder: A decoder used to decode `jsonValue`.
  public init(
    jsonValue: JSONSchema.Value,
    validator: JSONSchema.Validator = .shared,
    decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder()
  ) throws {
    try validator.validate(value: jsonValue, with: Self.jsonSchema)
    self = try decoder.decode(Self.self, from: jsonValue)
  }
}

// MARK: - Scalar Types

extension String: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .string() }
}

extension Bool: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .bool() }
}

extension Double: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .number() }
}

extension Float: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .number() }
}

extension Int8: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int16: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int32: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int64: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt8: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt16: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt32: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt64: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

@available(StreamParsing128BitIntegers, *)
extension Int128: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer() }
}

@available(StreamParsing128BitIntegers, *)
extension UInt128: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

// MARK: - Foundation

extension Data: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .string() }
}

extension Decimal: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema { .number() }
}

// MARK: - Generic Containers

extension Array: JSONSchemaRepresentable where Element: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema {
    .array(items: .schemaForAll(Element.jsonSchema))
  }
}

extension Dictionary: JSONSchemaRepresentable
where Key == String, Value: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema {
    .object(additionalProperties: Value.jsonSchema)
  }
}

extension Optional: JSONSchemaRepresentable where Wrapped: JSONSchemaRepresentable {
  public static var jsonSchema: JSONSchema {
    .object(anyOf: [Wrapped.jsonSchema, .null()])
  }
}

#if canImport(CoreGraphics)
  import CoreGraphics

  extension CGFloat: JSONSchemaRepresentable {
    public static var jsonSchema: JSONSchema { .number() }
  }
#endif
