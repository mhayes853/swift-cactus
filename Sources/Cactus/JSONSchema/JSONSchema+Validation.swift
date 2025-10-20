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
      case .boolean(false): throw ValidationError.falseSchema
      case .boolean(true): break
      case .object(let object): try self.validate(value: value, with: object)
      }
    }

    private func validate(value: Value, with object: Object) throws(ValidationError) {
      if let type = object.type, !type.contains(value.type) {
        throw ValidationError.typeMismatch(expected: type, got: value.type)
      }
      if let const = object.const, value != const {
        throw ValidationError.constMismatch(expected: const, got: value)
      }
      if let `enum` = object.enum, !`enum`.contains(value) {
        throw ValidationError.enumMismatch(expected: `enum`, got: value)
      }
    }
  }
}

// MARK: - ValidationError

extension JSONSchema {
  public enum ValidationError: Hashable, Error {
    case falseSchema
    case typeMismatch(expected: ValueType, got: ValueType)
    case constMismatch(expected: Value, got: Value)
    case enumMismatch(expected: [Value], got: Value)
  }
}
