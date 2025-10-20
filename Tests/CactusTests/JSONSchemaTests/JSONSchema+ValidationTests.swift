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
  for path: [KeyPath<JSONSchema, JSONSchema?> & Sendable] = []
) {
  expectContainsFailureReasons(schema, value, [reason], for: path)
}

private func expectContainsFailureReasons(
  _ schema: JSONSchema,
  _ value: JSONSchema.Value,
  _ reasons: [JSONSchema.ValidationError.Reason],
  for path: [KeyPath<JSONSchema, JSONSchema?> & Sendable] = []
) {
  do {
    try validator.validate(value: value, with: schema)
    Issue.record("Value should not validate for schema.")
  } catch {
    expectNoDifference(
      error.failures.contains { $0.subschemaPath == path && reasons.contains($0.reason) },
      true
    )
  }
}

private let validator = JSONSchema.Validator()
