// MARK: - Validator

extension JSONSchema {
  /// A class for validating JSON values against a ``JSONSchema``.
  ///
  /// You can use this to validate tool parameter output from a ``CactusLanguageModel``.
  /// ```swift
  /// let functionDefinition = CactusLanguageModel.FunctionDefinition(
  ///   name: "search",
  ///   description: "Find something",
  ///   parameters: .object(
  ///     valueSchema: .object(
  ///       properties: [
  ///         "query": .object(valueSchema: .string(minLength: 1))
  ///       ]
  ///     )
  ///   )
  /// )
  /// let completion = try model.chatCompletion(
  ///   messages: messages,
  ///   functions: [functionDefinition]
  /// )
  ///
  /// for functionCall in completion.functionCalls {
  ///   try JSONSchema.Validator.shared.validate(
  ///     value: .object(functionCall.arguments),
  ///     with: functionDefinition.parameters
  ///   )
  /// }
  /// ```
  public final class Validator: Sendable {
    /// A shared validator instance.
    public static let shared = Validator()

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
        guard let numberSchema = object.valueSchema?.number else { break }
        self.validate(number: number, with: numberSchema, in: &context)
      case .string(let string):
        guard let stringSchema = object.valueSchema?.string else { break }
        self.validate(string: string, with: stringSchema, in: &context)
      case .array(let array):
        guard let arraySchema = object.valueSchema?.array else { break }
        self.validate(array: array, with: arraySchema, in: &context)
      case .object(let obj):
        guard let objectSchema = object.valueSchema?.object else { break }
        self.validate(object: obj, with: objectSchema, in: &context)
      default:
        break
      }

      if let notSchema = object.not, self.isValid(value: value, with: notSchema) {
        context.appendFailureReason(.matchesNot(schema: notSchema))
      }

      if let ifSchema = object.if {
        self.validateControlFlow(
          value: value,
          with: ifSchema,
          thenSchema: object.then,
          elseSchema: object.else,
          in: &context
        )
      }

      if let allOfSchemas = object.allOf {
        self.validateAllOf(value: value, with: allOfSchemas, in: &context)
      }
      if let anyOfSchemas = object.anyOf {
        self.validateAnyOf(value: value, with: anyOfSchemas, in: &context)
      }
      if let oneOfSchemas = object.oneOf {
        self.validateOneOf(value: value, with: oneOfSchemas, in: &context)
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

      var containsContext = Context(path: context.path, failures: [])
      let containsSchema = schema.contains ?? .object(valueSchema: nil)
      var doesContain = schema.contains == nil
      context.withPathSaveState { context, path in
        let itemSchemas =
          schema.items?.schemaPerItem(count: array.count, additionalItems: schema.additionalItems)
          ?? AnySequence<JSONSchema?>(repeatElement(nil, count: array.count))

        for (value, (index, itemSchema)) in zip(array, zip(array.indices, itemSchemas)) {
          context.path = path + [.arrayItem(index: index)]
          containsContext.path = context.path
          if let itemSchema {
            self.validate(value: value, with: itemSchema, in: &context)
          }

          if !doesContain {
            let containsFailureCount = containsContext.failures.count
            self.validate(value: value, with: containsSchema, in: &containsContext)
            doesContain = doesContain || containsContext.failures.count == containsFailureCount
          }
        }
      }

      if !doesContain {
        context.appendFailureReason(
          .arrayContainsMismatch(schema: containsSchema, failures: containsContext.failures)
        )
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

      var remainingRequiredProperties = Set(schema.required ?? [])
      context.withPathSaveState { context, path in
        let regexes =
          schema.patternProperties.map { self.regexes(for: $0.keys, in: &context) } ?? [:]
        for (property, value) in object {
          if let propertyNames = schema.propertyNames {
            context.path = path + [.objectProperty(property: property)]
            self.validate(value: .string(property), with: propertyNames, in: &context)
          }

          context.path = path + [.objectValue(property: property)]

          if let propertySchema = schema.properties?[property] ?? schema.additionalProperties {
            self.validate(value: value, with: propertySchema, in: &context)
          }

          let patterns = regexes.filter { $0.1.matches(property) }.map(\.key)
          let patternPropertySchemas = patterns.compactMap { schema.patternProperties?[$0] }
          for propertySchema in patternPropertySchemas {
            self.validate(value: value, with: propertySchema, in: &context)
          }

          remainingRequiredProperties.remove(property)
        }
      }

      if !remainingRequiredProperties.isEmpty {
        context.appendFailureReason(
          .objectMissingRequiredProperties(
            required: schema.required ?? [],
            missing: Array(remainingRequiredProperties)
          )
        )
      }
    }

    private func validateControlFlow(
      value: Value,
      with ifSchema: JSONSchema,
      thenSchema: JSONSchema?,
      elseSchema: JSONSchema?,
      in context: inout Context
    ) {
      context.withPathSaveState { context, path in
        if self.isValid(value: value, with: ifSchema) {
          if let thenSchema = thenSchema {
            context.path = path + [.then]
            self.validate(value: value, with: thenSchema, in: &context)
          }
        } else if let elseSchema = elseSchema {
          context.path = path + [.else]
          self.validate(value: value, with: elseSchema, in: &context)
        }
      }
    }

    private func validateAllOf(
      value: Value,
      with schemas: [JSONSchema],
      in context: inout Context
    ) {
      var allOfContext = Context(path: context.path, failures: [])
      allOfContext.withPathSaveState { context, path in
        for (subschema, index) in zip(schemas, schemas.indices) {
          context.path = path + [.allOf(index: index)]
          self.validate(value: value, with: subschema, in: &context)
        }
      }

      if !allOfContext.failures.isEmpty {
        context.appendFailureReason(.allOfMismatch(failures: allOfContext.failures))
      }
    }

    private func validateAnyOf(
      value: Value,
      with schemas: [JSONSchema],
      in context: inout Context
    ) {
      var anyOfContext = Context(path: context.path, failures: [])
      var hasMatch = false
      anyOfContext.withPathSaveState { context, path in
        for (subschema, index) in zip(schemas, schemas.indices) {
          context.path = path + [.anyOf(index: index)]
          if !hasMatch {
            let failureCount = context.failures.count
            self.validate(value: value, with: subschema, in: &context)
            hasMatch = context.failures.count == failureCount
          }
        }
      }

      if !hasMatch {
        context.appendFailureReason(.anyOfMismatch(failures: anyOfContext.failures))
      }
    }

    private func validateOneOf(
      value: Value,
      with schemas: [JSONSchema],
      in context: inout Context
    ) {
      var oneOfContext = Context(path: context.path, failures: [])
      var matchCount = 0
      oneOfContext.withPathSaveState { context, path in
        for (subschema, index) in zip(schemas, schemas.indices) {
          context.path = path + [.oneOf(index: index)]
          if matchCount <= 1 {
            let failureCount = context.failures.count
            self.validate(value: value, with: subschema, in: &context)
            matchCount += context.failures.count == failureCount ? 1 : 0
          }
        }
      }

      if matchCount != 1 {
        context.appendFailureReason(.oneOfMismatch(failures: oneOfContext.failures))
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
        JSONSchema.ValidationError.Failure(path: self.path, reason: reason)
      )
    }
  }
}

// MARK: - ValidationError

extension JSONSchema {
  /// An error thrown when ``Validator/validate(value:with:)`` fails.
  public struct ValidationError: Hashable, Error {
    /// All validation failures against the schema.
    public let failures: [Failure]
  }
}

extension JSONSchema.ValidationError {
  /// The reason for a validation failure.
  public enum Reason: Hashable, Sendable {
    // MARK: - False Schema

    /// The schema was a boolean set to `false`.
    case falseSchema

    // MARK: - Top Level Mismatches

    /// A ``JSONSchema/Object/type`` mismatch.
    case typeMismatch(expected: JSONSchema.ValueType)

    /// A ``JSONSchema/Object/const`` mismatch.
    case constMismatch(expected: JSONSchema.Value)

    /// A ``JSONSchema/Object/enum`` mismatch.
    case enumMismatch(expected: [JSONSchema.Value])

    /// A value matched ``JSONSchema/Object/not`` successfully.
    case matchesNot(schema: JSONSchema)

    /// A value did not match all schemas from ``JSONSchema/Object/allOf``.
    case allOfMismatch(failures: [Failure])

    /// A value did not match any of the schemas from ``JSONSchema/Object/anyOf``.
    case anyOfMismatch(failures: [Failure])

    /// A value did not match exactly one of the schemas from ``JSONSchema/Object/oneOf``.
    case oneOfMismatch(failures: [Failure])

    // MARK: - Integer

    /// An integer was not a multiple of ``JSONSchema/ValueSchema/Integer/multipleOf``.
    case notMultipleOf(integer: Int)

    /// An integer was below the minimum allowed value.
    case belowMinimum(inclusive: Bool, integer: Int)

    /// An integer was above the maximum allowed value.
    case aboveMaximum(inclusive: Bool, integer: Int)

    // MARK: - Number

    /// A number was not a multiple of ``JSONSchema/ValueSchema/Number/multipleOf``.
    case notMultipleOf(number: Double)

    /// A number was below the minimum allowed value.
    case belowMinimum(inclusive: Bool, number: Double)

    /// A number was above the maximum allowed value.
    case aboveMaximum(inclusive: Bool, number: Double)

    // MARK: - String

    /// A string's length was too short.
    case stringLengthTooShort(minimum: Int)

    /// A string's length was too long.
    case stringLengthTooLong(maximum: Int)

    /// A string failed to match a regular expression pattern.
    case stringPatternMismatch(pattern: String)

    // MARK: - Array

    /// An array's length was too short.
    case arrayLengthTooShort(minimum: Int)

    /// An array's length was too long.
    case arrayLengthTooLong(maximum: Int)

    /// An array did not have an item that matched ``JSONSchema/ValueSchema/Array/contains``.
    case arrayContainsMismatch(schema: JSONSchema, failures: [Failure])

    /// The items of an array were not unique when ``JSONSchema/ValueSchema/Array/uniqueItems``
    /// was true.
    case arrayItemsNotUnique

    // MARK: - Object

    /// An object didn't have enough properties.
    case objectPropertiesTooShort(minimum: Int)

    /// An object had too many properties.
    case objectPropertiesTooLong(maximum: Int)

    /// An object was missing required properties.
    case objectMissingRequiredProperties(required: [String], missing: [String])

    // MARK: - Regex

    /// A regular expression pattern could not be compiled.
    case patternCompilationError(pattern: String)
  }
}

extension JSONSchema.ValidationError {
  /// An enum for an identifier that references a subschema in a ``JSONSchema``.
  public enum PathElement: Hashable, Sendable {
    /// Validating an array item.
    case arrayItem(index: Int)

    /// Validating an object property name.
    case objectProperty(property: String)

    /// Validating an object property value.
    case objectValue(property: String)

    /// Validating against the ``JSONSchema/Object/then`` schema.
    case then

    /// Validating against the ``JSONSchema/Object/else`` schema.
    case `else`

    /// Validating against the ``JSONSchema/Object/allOf`` schemas.
    case allOf(index: Int)

    /// Validating against the ``JSONSchema/Object/anyOf`` schemas.
    case anyOf(index: Int)

    /// Validating against the ``JSONSchema/Object/oneOf`` schemas.
    case oneOf(index: Int)
  }
}

extension JSONSchema.ValidationError {
  /// An instance of a single failure when validating a value against a ``JSONSchema``.
  public struct Failure: Hashable, Sendable {
    /// An array of ``PathElement`` instances that point to the cite of the failure.
    public let path: [PathElement]

    /// The ``Reason`` for the failure.
    public let reason: Reason

    /// Creates a failure.
    ///
    /// - Parameters:
    ///   - path: An array of ``PathElement`` instances that point to the cite of the failure.
    ///   - reason: The ``Reason`` for the failure.
    public init(
      path: [JSONSchema.ValidationError.PathElement],
      reason: JSONSchema.ValidationError.Reason
    ) {
      self.path = path
      self.reason = reason
    }
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
