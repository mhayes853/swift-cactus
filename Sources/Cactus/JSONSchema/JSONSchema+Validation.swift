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

    /// Validates the specified `value` against the specified ``JSONSchema``.
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

    /// Returns true if the specified `value` is valid against the specified ``JSONSchema``.
    ///
    /// - Parameters:
    ///   - value: The ``Value`` to validate.
    ///   - schema: The ``JSONSchema`` to validate against.
    public func isValid(value: Value, with schema: JSONSchema) -> Bool {
      do {
        try self.validate(value: value, with: schema)
        return true
      } catch {
        return false
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
      case .string(let string):
        guard let stringSchema = object.valueSchema?.string else { return }
        self.validate(string: string, with: stringSchema, in: &context)
      case .array(let array):
        guard let arraySchema = object.valueSchema?.array else { return }
        self.validate(array: array, with: arraySchema, in: &context)
      case .object(let obj):
        guard let objectSchema = object.valueSchema?.object else { return }
        self.validate(object: obj, with: objectSchema, in: &context)
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

    private func validate(
      string: String,
      with schema: ValueSchema.String,
      in context: inout Context
    ) {
      if let minLength = schema.minLength, string.utf8.count < minLength {
        context.appendFailureReason(.stringLengthTooShort(minimum: minLength))
      }
      if let maxLength = schema.maxLength, string.utf8.count > maxLength {
        context.appendFailureReason(.stringLengthTooLong(maximum: maxLength))
      }
      if let pattern = schema.pattern {
        guard let regex = self.regexes(for: CollectionOfOne(pattern), in: &context)[pattern] else {
          return
        }
        if !regex.matches(string) {
          context.appendFailureReason(.stringPatternMismatch(pattern: pattern))
        }
      }
    }

    private func validate(
      array: [JSONSchema.Value],
      with schema: ValueSchema.Array,
      in context: inout Context
    ) {
      if let minItems = schema.minItems, array.count < minItems {
        context.appendFailureReason(.arrayLengthTooShort(minimum: minItems))
      }
      if let maxItems = schema.maxItems, array.count > maxItems {
        context.appendFailureReason(.arrayLengthTooLong(maximum: maxItems))
      }
      if schema.uniqueItems == true && !array.isUnique {
        context.appendFailureReason(.arrayItemsNotUnique)
      }
      if let containsSchema = schema.contains,
        !array.contains(where: { self.isValid(value: $0, with: containsSchema) })
      {
        context.appendFailureReason(.arrayContainsMismatch(schema: containsSchema))
      }

      if let items = schema.items {
        context.withPathSaveState { context, path in
          let itemSchemas = items.schemaPerItem(
            count: array.count,
            additionalItems: schema.additionalItems
          )
          for (value, (index, itemSchema)) in zip(array, zip(array.indices, itemSchemas)) {
            context.path = path + [.arrayItem(index: index)]
            guard let itemSchema else { continue }
            self.validate(value: value, with: itemSchema, in: &context)
          }
        }
      }
    }

    private func validate(
      object: [String: JSONSchema.Value],
      with schema: ValueSchema.Object,
      in context: inout Context
    ) {
      if let minProperties = schema.minProperties, object.count < minProperties {
        context.appendFailureReason(.objectPropertiesTooShort(minimum: minProperties))
      }
      if let maxProperties = schema.maxProperties, object.count > maxProperties {
        context.appendFailureReason(.objectPropertiesTooLong(maximum: maxProperties))
      }
      if let required = schema.required {
        let missingProperties = Array(Set(required).subtracting(object.keys))
        if !missingProperties.isEmpty {
          context.appendFailureReason(
            .objectMissingRequiredProperties(required: required, missing: missingProperties)
          )
        }
      }
      if let propertyNames = schema.propertyNames {
        context.withPathSaveState { context, path in
          for property in object.keys {
            context.path = path + [.objectProperty(property: property)]
            self.validate(value: .string(property), with: propertyNames, in: &context)
          }
        }
      }
      if let properties = schema.properties {
        context.withPathSaveState { context, path in
          for (property, value) in object {
            context.path = path + [.objectValue(property: property)]
            let propertySchema = properties[property] ?? schema.additionalProperties
            guard let propertySchema else { continue }
            self.validate(value: value, with: propertySchema, in: &context)
          }
        }
      }
      if let patternProperties = schema.patternProperties {
        let regexes = self.regexes(for: patternProperties.keys, in: &context)
        context.withPathSaveState { context, path in
          for (property, value) in object {
            let pattern = regexes.first { $0.1.matches(property) }?.key
            guard let propertySchema = pattern.flatMap({ patternProperties[$0] }) else { continue }

            context.path = path + [.objectValue(property: property)]
            self.validate(value: value, with: propertySchema, in: &context)
          }
        }
      }
    }

    private func regexes(
      for patterns: some Sequence<String>,
      in context: inout Context
    ) -> [String: RegularExpression] {
      self.regexCache.withLock { cache in
        var regexes = [String: RegularExpression]()
        for pattern in patterns {
          if let regex = cache[pattern] {
            regexes[pattern] = regex
          } else if let regex = try? RegularExpression(pattern) {
            regexes[pattern] = regex
            cache[pattern] = regex
          } else {
            context.appendFailureReason(.patternCompilationError(pattern: pattern))
          }
        }
        return regexes
      }
    }
  }
}

// MARK: - Context

extension JSONSchema.Validator {
  private struct Context: Sendable {
    var path = [JSONSchema.ValidationError.PathElement]()
    private(set) var failures = [JSONSchema.ValidationError.Failure]()

    mutating func withPathSaveState(
      operation: (inout Context, [JSONSchema.ValidationError.PathElement]) -> Void
    ) {
      let path = self.path
      operation(&self, path)
      self.path = path
    }

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

    case stringLengthTooShort(minimum: Int)
    case stringLengthTooLong(maximum: Int)
    case stringPatternMismatch(pattern: String)

    case arrayLengthTooShort(minimum: Int)
    case arrayLengthTooLong(maximum: Int)
    case arrayContainsMismatch(schema: JSONSchema)
    case arrayItemsNotUnique

    case objectPropertiesTooShort(minimum: Int)
    case objectPropertiesTooLong(maximum: Int)
    case objectMissingRequiredProperties(required: [String], missing: [String])

    case patternCompilationError(pattern: String)
  }
}

extension JSONSchema.ValidationError {
  public enum PathElement: Hashable, Sendable {
    case arrayItem(index: Int)
    case objectProperty(property: String)
    case objectValue(property: String)
  }
}

extension JSONSchema.ValidationError {
  public struct Failure: Hashable, Sendable {
    public let subschemaPath: [PathElement]
    public let reason: Reason
  }
}

// MARK: - Helpers

extension JSONSchema.ValueSchema.Array.Items {
  fileprivate func schemaPerItem(
    count: Int,
    additionalItems: JSONSchema?
  ) -> AnySequence<JSONSchema?> {
    switch (self, additionalItems) {
    case (.schemaForAll(let schema), _):
      return AnySequence(repeatElement(schema, count: count) as Repeated<JSONSchema?>)
    case (.itemsSchemas(let itemsSchemas), let additionalItems):
      let repetition = repeatElement(additionalItems, count: max(0, count - itemsSchemas.count))
      return AnySequence(chain(itemsSchemas, repetition))
    }
  }
}
