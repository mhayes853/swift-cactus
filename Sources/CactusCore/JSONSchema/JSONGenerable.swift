import Foundation
import StreamParsing

// MARK: - JSONGenerable

/// A type that can generate and decode itself from a JSON schema value.
public protocol JSONGenerable: StreamParseable {
  /// The JSON schema describing this type.
  static var jsonSchema: JSONSchema { get }
}

extension JSONGenerable where Self: Decodable {
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

extension String: JSONGenerable {
  public static var jsonSchema: JSONSchema { .string() }
}

extension Bool: JSONGenerable {
  public static var jsonSchema: JSONSchema { .bool() }
}

extension Double: JSONGenerable {
  public static var jsonSchema: JSONSchema { .number() }
}

extension Float: JSONGenerable {
  public static var jsonSchema: JSONSchema { .number() }
}

extension Int8: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int16: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int32: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int64: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension Int: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt8: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt16: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt32: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt64: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

extension UInt: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

@available(StreamParsing128BitIntegers, *)
extension Int128: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer() }
}

@available(StreamParsing128BitIntegers, *)
extension UInt128: JSONGenerable {
  public static var jsonSchema: JSONSchema { .integer(minimum: 0) }
}

// MARK: - Foundation

extension Data: JSONGenerable {
  public static var jsonSchema: JSONSchema { .string() }
}

extension Decimal: JSONGenerable {
  public static var jsonSchema: JSONSchema { .number() }
}

// MARK: - Generic Containers

extension Array: JSONGenerable where Element: JSONGenerable {
  public static var jsonSchema: JSONSchema {
    .array(items: .schemaForAll(Element.jsonSchema))
  }
}

extension Dictionary: JSONGenerable where Key == String, Value: JSONGenerable {
  public static var jsonSchema: JSONSchema {
    .object(additionalProperties: Value.jsonSchema)
  }
}

extension Optional: JSONGenerable where Wrapped: JSONGenerable {
  public static var jsonSchema: JSONSchema {
    .object(anyOf: [Wrapped.jsonSchema, .null()])
  }
}

#if canImport(CoreGraphics)
  import CoreGraphics

  extension CGFloat: JSONGenerable {
    public static var jsonSchema: JSONSchema { .number() }
  }
#endif
