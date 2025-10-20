// MARK: - Validator

extension JSONSchema {
  /// A class for validating JSON values against a ``JSONSchema``.
  ///
  /// For performance, you should create and hold a single instance of a validator throughout the
  /// lifetime of your application.
  public final class Validator: Sendable {
    private let regexCache = Lock([String: RegularExpression]())

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
        throw ValidationError.falseSchema
      case .boolean(true):
        return
      case .object(let object):
        if let type = object.type, type.contains(value.type) == false {
          throw ValidationError.typeMismatch(expected: type, got: value.type)
        }
      }
    }
  }
}

// MARK: - ValidationError

extension JSONSchema {
  public enum ValidationError: Hashable, Error {
    case falseSchema
    case typeMismatch(expected: ValueType, got: ValueType)
  }
}
