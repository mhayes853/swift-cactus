import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchemaValidation tests` {
  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Always Validates For True Schema`(value: JSONSchema.Value) {
    expectValidates(true, value)
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Always Validates For Empty Schema`(value: JSONSchema.Value) {
    expectValidates(.object(valueSchema: nil), value)
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Never Validates For False Schema`(value: JSONSchema.Value) {
    expectContainsFailureReason(false, value, .falseSchema)
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Never Validates For Empty Type Union`(value: JSONSchema.Value) {
    expectContainsFailureReason(
      .object(valueSchema: .union()),
      value,
      .typeMismatch(expected: [])
    )
  }

  @Test
  func `Validates Null Value For Null Type`() {
    expectValidates(.object(valueSchema: .null), .null)
  }

  @Test
  func `Captures Multiple Failure Reasons`() {
    let schema = JSONSchema.object(valueSchema: .null, const: 1)
    expectContainsFailureReasons(
      schema,
      2,
      [.typeMismatch(expected: .null), .constMismatch(expected: 1)]
    )

  }

  @Test(arguments: [JSONSchema.Value.string("blob"), true, 10, [], [:], 10.0])
  func `Invalid When Validating Non-Null Value Against Null Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .null),
      value,
      .typeMismatch(expected: .null)
    )
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Integer Value Against Integer Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .integer()),
      value,
      .typeMismatch(expected: .integer)
    )
  }

  @Test
  func `Validates Integer For Number Type Schema`() {
    expectValidates(.object(valueSchema: .number()), 10)
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:]])
  func `Invalid When Validating Non-Number Value Against Number Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .number()),
      value,
      .typeMismatch(expected: .number)
    )
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Boolean Value Against Boolean Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .boolean),
      value,
      .typeMismatch(expected: .boolean)
    )
  }

  @Test(arguments: [JSONSchema.Value.null, 10, [], [:], 10.0])
  func `Invalid When Validating Non-String Value Against String Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .string()),
      value,
      .typeMismatch(expected: .string)
    )
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [:], 10.0])
  func `Invalid When Validating Non-Array Value Against Array Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .array()),
      value,
      .typeMismatch(expected: .array)
    )
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], 10.0])
  func `Invalid When Validating Non-Object Value Against Object Schema`(
    value: JSONSchema.Value
  ) {
    expectContainsFailureReason(
      .object(valueSchema: .object()),
      value,
      .typeMismatch(expected: .object)
    )
  }

  @Test
  func `Is Valid When Value Has A Type That Is Part Of The Union`() {
    let schema = JSONSchema.object(
      valueSchema: .union(string: .string(), isBoolean: true, isNullable: true)
    )
    expectValidates(schema, .null)
    expectValidates(schema, true)
    expectValidates(schema, "hello")
  }

  @Test
  func `Invalid When Value Doesn't Match Const`() {
    let schema = JSONSchema.object(valueSchema: .string(), const: "blob")
    expectContainsFailureReason(schema, "blob jr", .constMismatch(expected: "blob"))
  }

  @Test
  func `Validates When Value Matches Const`() {
    let schema = JSONSchema.object(valueSchema: .string(), const: "blob")
    expectValidates(schema, "blob")
  }

  @Test
  func `Invalid When Value Not Contained In Enum`() {
    let schema = JSONSchema.object(valueSchema: .string(), enum: ["blob", "blob jr"])
    expectContainsFailureReason(schema, "blob jr jr", .enumMismatch(expected: ["blob", "blob jr"]))
  }

  @Test
  func `Validates When Value Contained In Enum`() {
    let schema = JSONSchema.object(valueSchema: .string(), enum: ["blob", "blob jr"])
    expectValidates(schema, "blob")
    expectValidates(schema, "blob jr")
  }

  @Test
  func `Integer Value Must Be Multiple Of MultipleOf`() {
    let schema = JSONSchema.object(valueSchema: .integer(multipleOf: 2))
    expectValidates(schema, 4)
    expectContainsFailureReason(schema, 3, .notMultipleOf(integer: 2))
  }

  @Test
  func `Integer Value Must Be Greater Than Or Equal To Inclusive Minimum`() {
    let schema = JSONSchema.object(valueSchema: .integer(minimum: 2))
    expectValidates(schema, 4)
    expectValidates(schema, 2)
    expectContainsFailureReason(schema, 1, .belowMinimum(inclusive: true, integer: 2))
  }

  @Test
  func `Integer Value Must Be Greater Than Exclusive Minimum`() {
    let schema = JSONSchema.object(valueSchema: .integer(exclusiveMinimum: 2))
    expectValidates(schema, 4)
    expectContainsFailureReason(schema, 2, .belowMinimum(inclusive: false, integer: 2))
    expectContainsFailureReason(schema, 1, .belowMinimum(inclusive: false, integer: 2))
  }

  @Test
  func `Integer Value Must Be Less Than Or Equal To Inclusive Maximum`() {
    let schema = JSONSchema.object(valueSchema: .integer(maximum: 4))
    expectValidates(schema, 4)
    expectValidates(schema, 2)
    expectContainsFailureReason(schema, 5, .aboveMaximum(inclusive: true, integer: 4))
  }

  @Test
  func `Integer Value Must Be Less Than Exclusive Maximum`() {
    let schema = JSONSchema.object(valueSchema: .integer(exclusiveMaximum: 4))
    expectValidates(schema, 2)
    expectContainsFailureReason(schema, 4, .aboveMaximum(inclusive: false, integer: 4))
    expectContainsFailureReason(schema, 5, .aboveMaximum(inclusive: false, integer: 4))
  }

  @Test
  func `Number Value Must Be Multiple Of MultipleOf`() {
    let schema = JSONSchema.object(valueSchema: .number(multipleOf: 2.5))
    expectValidates(schema, 5)
    expectContainsFailureReason(schema, 4.2, .notMultipleOf(number: 2.5))
  }

  @Test
  func `Number Value Must Be Greater Than Or Equal To Inclusive Minimum`() {
    let schema = JSONSchema.object(valueSchema: .number(minimum: 2))
    expectValidates(schema, 4)
    expectValidates(schema, 2.12)
    expectContainsFailureReason(schema, 1.8, .belowMinimum(inclusive: true, number: 2))
  }

  @Test
  func `Number Value Must Be Greater Than Exclusive Minimum`() {
    let schema = JSONSchema.object(valueSchema: .number(exclusiveMinimum: 2))
    expectValidates(schema, 4)
    expectContainsFailureReason(schema, 2, .belowMinimum(inclusive: false, number: 2))
    expectContainsFailureReason(schema, 1.8, .belowMinimum(inclusive: false, number: 2))
  }

  @Test
  func `Number Value Must Be Less Than Or Equal To Inclusive Maximum`() {
    let schema = JSONSchema.object(valueSchema: .number(maximum: 4))
    expectValidates(schema, 4)
    expectValidates(schema, 2.2)
    expectContainsFailureReason(schema, 5.1, .aboveMaximum(inclusive: true, number: 4))
  }

  @Test
  func `Number Value Must Be Less Than Exclusive Maximum`() {
    let schema = JSONSchema.object(valueSchema: .number(exclusiveMaximum: 4))
    expectValidates(schema, 2.1)
    expectContainsFailureReason(schema, 4, .aboveMaximum(inclusive: false, number: 4))
    expectContainsFailureReason(schema, 5.3, .aboveMaximum(inclusive: false, number: 4))
  }

  @Test
  func `Boolean Value Valid When Type Is Boolean`() {
    let schema = JSONSchema.object(valueSchema: .boolean)
    expectValidates(schema, true)
    expectValidates(schema, false)
  }

  @Test
  func `String Must Have Minimum Length`() {
    let schema = JSONSchema.object(valueSchema: .string(minLength: 5))
    expectValidates(schema, "hello")
    expectValidates(schema, "world this is a test")
    expectValidates(schema, "✅🔴🤖")
    expectContainsFailureReason(schema, "hi", .stringLengthTooShort(minimum: 5))
    expectContainsFailureReason(schema, "hi", .stringLengthTooShort(minimum: 5))
  }

  @Test
  func `String Must Have Less Than Maximum Length`() {
    let schema = JSONSchema.object(valueSchema: .string(maxLength: 4))
    expectValidates(schema, "hell")
    expectValidates(schema, "hi")
    expectContainsFailureReason(schema, "world this is a test", .stringLengthTooLong(maximum: 4))
    expectContainsFailureReason(schema, "✅🔴🤖", .stringLengthTooLong(maximum: 4))
  }

  @Test
  func `String Pattern Must Be A Valid Regex`() {
    let schema = JSONSchema.object(valueSchema: .string(pattern: "["))
    expectContainsFailureReason(schema, "abc", .patternCompilationError(pattern: "["))
  }

  @Test
  func `String Must Match Pattern`() {
    let schema = JSONSchema.object(valueSchema: .string(pattern: "[0-9]+"))
    expectValidates(schema, "1234")
    expectContainsFailureReason(schema, "abc", .stringPatternMismatch(pattern: "[0-9]+"))
    expectContainsFailureReason(schema, "", .stringPatternMismatch(pattern: "[0-9]+"))
  }

  @Test
  func `Array Must Have Minimum Items`() {
    let schema = JSONSchema.object(valueSchema: .array(minItems: 2))
    expectValidates(schema, [1, 2])
    expectValidates(schema, [1, 2, 3])
    expectContainsFailureReason(schema, [1], .arrayLengthTooShort(minimum: 2))
  }

  @Test
  func `Array Must Not Have More Than Maximum Items`() {
    let schema = JSONSchema.object(valueSchema: .array(maxItems: 1))
    expectValidates(schema, [1])
    expectValidates(schema, [])
    expectContainsFailureReason(schema, [1, 2], .arrayLengthTooLong(maximum: 1))
  }

  @Test
  func `Array Must Be Unique When Unique Specified`() {
    let schema = JSONSchema.object(valueSchema: .array(uniqueItems: true))
    expectValidates(schema, [1, 2])
    expectContainsFailureReason(schema, [1, 1], .arrayItemsNotUnique)
  }

  @Test
  func `Array Must Contain At Least One Element Matching Contains Schema`() {
    let containsSchema = JSONSchema.object(valueSchema: .string())
    let schema = JSONSchema.object(valueSchema: .array(contains: containsSchema))

    expectValidates(schema, [1, "2"])
    expectContainsFailureReason(
      schema,
      [1, 2],
      .arrayContainsMismatch(
        schema: containsSchema,
        failures: [
          JSONSchema.ValidationError.Failure(
            path: [.arrayItem(index: 0)],
            reason: .typeMismatch(expected: .string)
          ),
          JSONSchema.ValidationError.Failure(
            path: [.arrayItem(index: 1)],
            reason: .typeMismatch(expected: .string)
          )
        ]
      )
    )
  }

  @Test
  func `All Array Items Must Conform To Schema`() {
    let itemSchema = JSONSchema.object(valueSchema: .number())
    let schema = JSONSchema.object(valueSchema: .array(items: .schemaForAll(itemSchema)))

    expectValidates(schema, [])
    expectValidates(schema, [1, 2])
    expectContainsFailureReason(
      schema,
      [1, "2"],
      .typeMismatch(expected: .number),
      for: [.arrayItem(index: 1)]
    )
  }

  @Test
  func `First N Array Items Must Conform To Schema`() {
    let item1Schema = JSONSchema.object(valueSchema: .number())
    let item2Schema = JSONSchema.object(valueSchema: .string())
    let schema = JSONSchema.object(
      valueSchema: .array(items: .itemsSchemas([item1Schema, item2Schema]))
    )

    expectValidates(schema, [1])
    expectValidates(schema, [1, "2"])
    expectValidates(schema, [1, "2", true])
    expectContainsFailureReason(
      schema,
      [1, 2],
      .typeMismatch(expected: .string),
      for: [.arrayItem(index: 1)]
    )
  }

  @Test
  func `Array Doesn't Allow Additional Items When Specified`() {
    let item1Schema = JSONSchema.object(valueSchema: .number())
    let item2Schema = JSONSchema.object(valueSchema: .string())
    let schema = JSONSchema.object(
      valueSchema: .array(items: .itemsSchemas([item1Schema, item2Schema]), additionalItems: false)
    )

    expectContainsFailureReason(
      schema,
      [1, "2", true],
      .falseSchema,
      for: [.arrayItem(index: 2)]
    )
  }

  @Test
  func `Array Allows Additional Items According To The Specified Schema`() {
    let item1Schema = JSONSchema.object(valueSchema: .number())
    let item2Schema = JSONSchema.object(valueSchema: .string())
    let additionalSchema = JSONSchema.object(valueSchema: .boolean)
    let schema = JSONSchema.object(
      valueSchema: .array(
        items: .itemsSchemas([item1Schema, item2Schema]),
        additionalItems: additionalSchema
      )
    )

    expectValidates(schema, [1, "2", true])
    expectContainsFailureReason(
      schema,
      [1, "2", "true"],
      .typeMismatch(expected: .boolean),
      for: [.arrayItem(index: 2)]
    )
  }

  @Test
  func `Object Must Have Minimum Properties`() {
    let schema = JSONSchema.object(valueSchema: .object(minProperties: 2))
    expectValidates(schema, ["a": 1, "b": 2])
    expectContainsFailureReason(schema, ["a": 1], .objectPropertiesTooShort(minimum: 2))
  }

  @Test
  func `Object Must Have Maximum Properties`() {
    let schema = JSONSchema.object(valueSchema: .object(maxProperties: 2))
    expectValidates(schema, ["a": 1, "b": 2])
    expectValidates(schema, [:])
    expectContainsFailureReason(
      schema,
      ["a": 1, "b": 2, "c": 3],
      .objectPropertiesTooLong(maximum: 2)
    )
  }

  @Test
  func `Object Must Have All Required Properties`() {
    let schema = JSONSchema.object(valueSchema: .object(required: ["a", "b"]))
    expectValidates(schema, ["a": 1, "b": 2])
    expectValidates(schema, ["a": 1, "b": 2, "c": 3])
    expectContainsFailureReason(
      schema,
      ["a": 1],
      .objectMissingRequiredProperties(required: ["a", "b"], missing: ["b"])
    )
  }

  @Test
  func `Object Property Names Must Match Appropriate Schema`() {
    let nameSchema = JSONSchema.object(valueSchema: .string(minLength: 3))
    let schema = JSONSchema.object(valueSchema: .object(propertyNames: nameSchema))
    expectValidates(schema, ["abc": 1, "def": true])
    expectContainsFailureReason(
      schema,
      ["a": 1, "b": true],
      .stringLengthTooShort(minimum: 3),
      for: [.objectProperty(property: "a")]
    )
    expectContainsFailureReason(
      schema,
      ["a": 1, "b": true],
      .stringLengthTooShort(minimum: 3),
      for: [.objectProperty(property: "b")]
    )
  }

  @Test
  func `Object Values Must Match Assigned Schemas`() {
    let p1Schema = JSONSchema.object(valueSchema: .string())
    let p2Schema = JSONSchema.object(valueSchema: .number())
    let schema = JSONSchema.object(
      valueSchema: .object(properties: ["a": p1Schema, "b": p2Schema])
    )

    expectValidates(schema, ["a": "hello"])
    expectValidates(schema, [:])
    expectValidates(schema, ["a": "hello", "b": 123])
    expectValidates(schema, ["a": "hello", "b": 123, "c": true])
    expectContainsFailureReason(
      schema,
      ["a": 1, "b": true],
      .typeMismatch(expected: .string),
      for: [.objectValue(property: "a")]
    )
    expectContainsFailureReason(
      schema,
      ["a": 1, "b": true],
      .typeMismatch(expected: .number),
      for: [.objectValue(property: "b")]
    )
  }

  @Test
  func `Object Forbids Additional Properties When Specified`() {
    let p1Schema = JSONSchema.object(valueSchema: .string())
    let p2Schema = JSONSchema.object(valueSchema: .number())
    let schema = JSONSchema.object(
      valueSchema: .object(properties: ["a": p1Schema, "b": p2Schema], additionalProperties: false)
    )
    expectContainsFailureReason(
      schema,
      ["a": "hello", "b": 1, "c": true],
      .falseSchema,
      for: [.objectValue(property: "c")]
    )
  }

  @Test
  func `Object Ensures That All Additional Properties Are Validated By Schema`() {
    let p1Schema = JSONSchema.object(valueSchema: .string())
    let p2Schema = JSONSchema.object(valueSchema: .number())
    let additionalSchema = JSONSchema.object(valueSchema: .boolean)
    let schema = JSONSchema.object(
      valueSchema: .object(
        properties: ["a": p1Schema, "b": p2Schema],
        additionalProperties: additionalSchema
      )
    )
    expectValidates(schema, ["a": "hello", "b": 123, "c": true])
    expectValidates(schema, ["a": "hello", "b": 123, "c": true, "d": false])
    expectContainsFailureReason(
      schema,
      ["a": "hello", "b": 1, "c": 10],
      .typeMismatch(expected: .boolean),
      for: [.objectValue(property: "c")]
    )
  }

  @Test
  func `Object Pattern Matched Properties Must Match Associated Schema`() {
    let p1Schema = JSONSchema.object(valueSchema: .string())
    let p2Schema = JSONSchema.object(valueSchema: .number())
    let schema = JSONSchema.object(
      valueSchema: .object(patternProperties: ["[0-9]+": p2Schema, "[a-z]+": p1Schema])
    )
    expectValidates(schema, ["1": 1, "a": "hello"])
    expectValidates(schema, [:])
    expectValidates(schema, ["A": true])
    expectValidates(schema, ["1": 1, "a": "hello", "2": 2, "b": "world"])
    expectContainsFailureReason(
      schema,
      ["1": 1, "2": "two"],
      .typeMismatch(expected: .number),
      for: [.objectValue(property: "2")]
    )
    expectContainsFailureReason(
      schema,
      ["1a": "foo"],
      .typeMismatch(expected: .number),
      for: [.objectValue(property: "1a")]
    )
    expectContainsFailureReason(
      schema,
      ["a1": 12],
      .typeMismatch(expected: .string),
      for: [.objectValue(property: "a1")]
    )
  }

  @Test
  func `Object Pattern Matched Properties Must Be Valid Regexes`() {
    let schema = JSONSchema.object(valueSchema: .object(patternProperties: ["[": true]))
    expectContainsFailureReason(schema, [:], .patternCompilationError(pattern: "["))
  }

  @Test
  func `Value Must Not Match The Not Schema`() {
    let notSchema = JSONSchema.object(valueSchema: .null)
    let schema = JSONSchema.object(valueSchema: nil, not: notSchema)
    expectValidates(schema, "foo")
    expectContainsFailureReason(schema, .null, .matchesNot(schema: notSchema))
  }

  @Test
  func `Value Must Match Then When Matching If`() {
    let ifSchema = JSONSchema.object(valueSchema: .string())
    let thenSchema = JSONSchema.object(valueSchema: .string(minLength: 10))
    let schema = JSONSchema.object(valueSchema: nil, if: ifSchema, then: thenSchema)

    expectValidates(schema, 1)
    expectValidates(schema, "this is a string with some length")
    expectContainsFailureReason(
      schema,
      "blob",
      .stringLengthTooShort(minimum: 10),
      for: [.then]
    )
  }

  @Test
  func `Value Must Match Else When Not Matching If`() {
    let ifSchema = JSONSchema.object(valueSchema: .string())
    let elseSchema = JSONSchema.object(valueSchema: .number())
    let schema = JSONSchema.object(valueSchema: nil, if: ifSchema, else: elseSchema)

    expectValidates(schema, 1)
    expectValidates(schema, "this is a string with some length")
    expectContainsFailureReason(
      schema,
      true,
      .typeMismatch(expected: .number),
      for: [.else]
    )
  }

  @Test
  func `Value Must Match All Of The Defined Subschemas`() {
    let subSchema1 = JSONSchema.object(valueSchema: .string())
    let subSchema2 = JSONSchema.object(valueSchema: .string(minLength: 1))
    let schema = JSONSchema.object(valueSchema: nil, allOf: [subSchema1, subSchema2])

    expectValidates(schema, "blob")
    expectContainsFailureReason(
      schema,
      "",
      .allOfMismatch(failures: [
        JSONSchema.ValidationError.Failure(
          path: [.allOf(index: 1)],
          reason: .stringLengthTooShort(minimum: 1)
        )
      ])
    )
    expectContainsFailureReason(
      schema,
      1,
      .allOfMismatch(failures: [
        JSONSchema.ValidationError.Failure(
          path: [.allOf(index: 0)],
          reason: .typeMismatch(expected: .string)
        ),
        JSONSchema.ValidationError.Failure(
          path: [.allOf(index: 1)],
          reason: .typeMismatch(expected: .string)
        )
      ])
    )
  }

  @Test
  func `Value Must Match Any Of The Defined Subschemas`() {
    let subSchema1 = JSONSchema.object(valueSchema: .number())
    let subSchema2 = JSONSchema.object(valueSchema: .string())
    let schema = JSONSchema.object(valueSchema: nil, anyOf: [subSchema1, subSchema2])

    expectValidates(schema, "blob")
    expectValidates(schema, 1)
    expectContainsFailureReason(
      schema,
      true,
      .anyOfMismatch(failures: [
        JSONSchema.ValidationError.Failure(
          path: [.anyOf(index: 0)],
          reason: .typeMismatch(expected: .number)
        ),
        JSONSchema.ValidationError.Failure(
          path: [.anyOf(index: 1)],
          reason: .typeMismatch(expected: .string)
        )
      ])
    )
  }

  @Test
  func `Value Must Match Exactly One Of The Defined Subschemas`() {
    let subSchema1 = JSONSchema.object(valueSchema: .string())
    let subSchema2 = JSONSchema.object(valueSchema: .string(minLength: 1))
    let schema = JSONSchema.object(valueSchema: nil, oneOf: [subSchema1, subSchema2])

    expectValidates(schema, "")
    expectContainsFailureReason(schema, "blob", .oneOfMismatch(failures: []))
    expectContainsFailureReason(
      schema,
      1,
      .oneOfMismatch(failures: [
        JSONSchema.ValidationError.Failure(
          path: [.oneOf(index: 0)],
          reason: .typeMismatch(expected: .string)
        ),
        JSONSchema.ValidationError.Failure(
          path: [.oneOf(index: 1)],
          reason: .typeMismatch(expected: .string)
        )
      ])
    )
  }

  @Test
  func `Validates Properly Against Complex Object Schema`() {
    let schema = JSONSchema.object(
      valueSchema: .object(
        properties: [
          "p1": .object(valueSchema: .string()),
          "p2": .object(
            valueSchema: .object(
              properties: [
                "p3": .object(valueSchema: .number()),
                "p4": .object(valueSchema: .boolean)
              ],
              required: ["p3", "p4"]
            )
          ),
          "p5": .object(valueSchema: .array(items: .schemaForAll(.object(valueSchema: .string()))))
        ]
      )
    )

    expectValidates(schema, [:])
    expectValidates(schema, ["p1": "blob", "p2": ["p3": 1.0, "p4": true], "p5": ["blob"]])
    expectContainsFailureReason(
      schema,
      ["p1": "blob", "p2": ["p3": 1.0], "p5": ["blob"]],
      .objectMissingRequiredProperties(required: ["p3", "p4"], missing: ["p4"]),
      for: [.objectValue(property: "p2")]
    )
    expectContainsFailureReason(
      schema,
      ["p1": "blob", "p2": ["p3": "1.0", "p4": true], "p5": ["blob"]],
      .typeMismatch(expected: .number),
      for: [.objectValue(property: "p2"), .objectValue(property: "p3")]
    )
    expectContainsFailureReason(
      schema,
      ["p1": "blob", "p2": ["p3": 1.0, "p4": true], "p5": [1]],
      .typeMismatch(expected: .string),
      for: [.objectValue(property: "p5"), .arrayItem(index: 0)]
    )
  }
}

private func expectValidates(_ schema: JSONSchema, _ value: JSONSchema.Value) {
  #expect(throws: Never.self) {
    try validator.validate(value: value, with: schema)
  }
}

private func expectContainsFailureReason(
  _ schema: JSONSchema,
  _ value: JSONSchema.Value,
  _ reason: JSONSchema.ValidationError.Reason,
  for path: [JSONSchema.ValidationError.PathElement] = []
) {
  expectContainsFailureReasons(schema, value, [reason], for: path)
}

private func expectContainsFailureReasons(
  _ schema: JSONSchema,
  _ value: JSONSchema.Value,
  _ reasons: [JSONSchema.ValidationError.Reason],
  for path: [JSONSchema.ValidationError.PathElement] = []
) {
  do {
    try validator.validate(value: value, with: schema)
    Issue.record("Value should not validate for schema.")
  } catch {
    expectNoDifference(
      error.failures.contains { $0.path == path && reasons.contains($0.reason) },
      true
    )
  }
}

private let validator = JSONSchema.Validator()
