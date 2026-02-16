import Foundation

// MARK: - TopLevelEncoder

/// A protocol for encoders that transform an `Encodable` value into a single top-level output.
public protocol TopLevelEncoder<Output> {
  /// The encoded output type.
  associatedtype Output

  /// Encodes the provided value.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: The encoded output.
  func encode<T: Encodable>(_ value: T) throws -> Output
}

// MARK: - Conformances

extension JSONEncoder: TopLevelEncoder {}
extension PropertyListEncoder: TopLevelEncoder {}

// MARK: - AnyTopLevelEncoder

/// Type-erased wrapper around any ``TopLevelEncoder``.
public struct AnyTopLevelEncoder<Encoded>: TopLevelEncoder {
  private let encoder: any TopLevelEncoder<Encoded>

  /// Creates a type-erased top-level encoder.
  ///
  /// - Parameter encoder: The encoder to wrap.
  public init(_ encoder: any TopLevelEncoder<Encoded>) {
    self.encoder = encoder
  }

  /// Encodes the provided value using the wrapped encoder.
  public func encode<T: Encodable>(_ value: T) throws -> Encoded {
    try self.encoder.encode(value)
  }
}

extension AnyTopLevelEncoder: @unchecked Sendable {}
