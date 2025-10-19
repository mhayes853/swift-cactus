import Foundation

// MARK: - Validator

extension JSONSchema {
  /// A class for validating JSON values against a ``JSONSchema``.
  ///
  /// For performance, you should create and hold a single instance of a validator throughout the
  /// lifetime of your application.
  public final class Validator: Sendable {
    private let regexCache = Lock([String: NSRegularExpression]())

    /// Creates a validator.
    public init() {}

    /// Validates the specified `value` against the schema held by this validator.
    ///
    /// - Parameters:
    ///   - value: The ``Value`` to validate.
    ///   - schema: The ``JSONSchema`` to validate against.
    /// - Throws: A ``ValidationError`` indicating the reason for the validation failure.
    public func validate(value: Value, with schema: JSONSchema) throws(ValidationError) {
      switch schema {
      case .boolean(false):
        throw ValidationError(reason: .falseSchema)
      case .boolean(true):
        return
      default:
        return
      }
    }
  }
}

// MARK: - ValidationError

extension JSONSchema {
  public struct ValidationError: Hashable, Error {
    public let reason: Reason

    public init(reason: Reason) {
      self.reason = reason
    }
  }
}

extension JSONSchema.ValidationError {
  public struct Reason: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    public static let falseSchema = Self(rawValue: "False Schema")
  }
}
