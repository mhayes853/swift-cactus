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
      var context = Context()
      self.validate(value: value, with: schema, in: &context)

      if !context.failures.isEmpty {
        throw ValidationError(failures: context.failures)
      }
    }

    private func validate(value: Value, with schema: JSONSchema, in context: inout Context) {
      switch schema {
      case .boolean(false): context.appendFailureReason(.falseSchema)
      case .boolean(true): break
      case .object(let object): self.validate(value: value, with: object, in: &context)
      }
    }

    private func validate(value: Value, with object: Object, in context: inout Context) {
      if let type = object.type, !type.isCompatible(with: value) {
        context.appendFailureReason(.typeMismatch(expected: type))
      }
      if let const = object.const, value != const {
        context.appendFailureReason(.constMismatch(expected: const))
      }
      if let `enum` = object.enum, !`enum`.contains(value) {
        context.appendFailureReason(.enumMismatch(expected: `enum`))
      }
      switch value {
      case .integer(let integer):
        if let integerSchema = object.valueSchema?.integer {
          self.validate(integer: integer, with: integerSchema, in: &context)
        }
        if let numberSchema = object.valueSchema?.number {
          self.validate(number: Double(integer), with: numberSchema, in: &context)
        }
      case .number(let number):
        guard let numberSchema = object.valueSchema?.number else { return }
        self.validate(number: number, with: numberSchema, in: &context)
      default:
        break
      }
    }

    private func validate(
      integer: Int,
      with schema: ValueSchema.Integer,
      in context: inout Context
    ) {
      if let multipleOf = schema.multipleOf, !integer.isMultiple(of: multipleOf) {
        context.appendFailureReason(.notMultipleOf(integer: multipleOf))
      }
      if let minimum = schema.minimum, integer < minimum {
        context.appendFailureReason(.belowMinimum(inclusive: true, integer: minimum))
      }
      if let exclusiveMinimum = schema.exclusiveMinimum, integer <= exclusiveMinimum {
        context.appendFailureReason(.belowMinimum(inclusive: false, integer: exclusiveMinimum))
      }
      if let maximum = schema.maximum, integer > maximum {
        context.appendFailureReason(.aboveMaximum(inclusive: true, integer: maximum))
      }
      if let exclusiveMaximum = schema.exclusiveMaximum, integer >= exclusiveMaximum {
        context.appendFailureReason(.aboveMaximum(inclusive: false, integer: exclusiveMaximum))
      }
    }

    private func validate(
      number: Double,
      with schema: ValueSchema.Number,
      in context: inout Context
    ) {
      if let multipleOf = schema.multipleOf,
        number.truncatingRemainder(dividingBy: multipleOf) != 0
      {
        context.appendFailureReason(.notMultipleOf(number: multipleOf))
      }
      if let minimum = schema.minimum, number < minimum {
        context.appendFailureReason(.belowMinimum(inclusive: true, number: minimum))
      }
      if let exclusiveMinimum = schema.exclusiveMinimum, number <= exclusiveMinimum {
        context.appendFailureReason(.belowMinimum(inclusive: false, number: exclusiveMinimum))
      }
      if let maximum = schema.maximum, number > maximum {
        context.appendFailureReason(.aboveMaximum(inclusive: true, number: maximum))
      }
      if let exclusiveMaximum = schema.exclusiveMaximum, number >= exclusiveMaximum {
        context.appendFailureReason(.aboveMaximum(inclusive: false, number: exclusiveMaximum))
      }
    }
  }
}

// MARK: - Context

extension JSONSchema.Validator {
  private struct Context: Sendable {
    var path = [KeyPath<JSONSchema, JSONSchema?> & Sendable]()
    private(set) var failures = [JSONSchema.ValidationError.Failure]()

    mutating func appendFailureReason(_ reason: JSONSchema.ValidationError.Reason) {
      self.failures.append(
        JSONSchema.ValidationError.Failure(subschemaPath: self.path, reason: reason)
      )
    }
  }
}

// MARK: - ValidationError

extension JSONSchema {
  public struct ValidationError: Hashable, Error {
    public let failures: [Failure]
  }
}

extension JSONSchema.ValidationError {
  public enum Reason: Hashable, Sendable {
    case falseSchema
    case typeMismatch(expected: JSONSchema.ValueType)
    case constMismatch(expected: JSONSchema.Value)
    case enumMismatch(expected: [JSONSchema.Value])

    case notMultipleOf(integer: Int)
    case belowMinimum(inclusive: Bool, integer: Int)
    case aboveMaximum(inclusive: Bool, integer: Int)

    case notMultipleOf(number: Double)
    case belowMinimum(inclusive: Bool, number: Double)
    case aboveMaximum(inclusive: Bool, number: Double)
  }
}

extension JSONSchema.ValidationError {
  public struct Failure: Hashable, Sendable {
    public let subschemaPath: [KeyPath<JSONSchema, JSONSchema?> & Sendable]
    public let reason: Reason
  }
}
