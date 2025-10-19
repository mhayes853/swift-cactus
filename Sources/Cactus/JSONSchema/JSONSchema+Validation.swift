// MARK: - Validate

extension JSONSchema {
  /// Validates the specified `value` against this schema.
  ///
  /// - Parameter value: The ``Value`` to validate.
  /// - Throws: A ``ValidationError`` indicating the reason for the validation failure.
  public func validate(value: Value) throws(ValidationError) {
    switch self {
    case .boolean(false):
      throw ValidationError(reason: .falseSchema)
    case .boolean(true):
      return
    default:
      return
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
