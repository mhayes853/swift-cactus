import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchemaValidation tests` {
  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Always Validates For True Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try validator.validate(value: value, with: .boolean(true))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Always Validates For Empty Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try validator.validate(value: value, with: .object(valueSchema: nil))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Never Validates For False Schema`(value: JSONSchema.Value) {
    #expect(throws: JSONSchema.ValidationError.falseSchema) {
      try validator.validate(value: value, with: .boolean(false))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", 10, [], [:], 10.0])
  func `Never Validates For Empty Type Union`(value: JSONSchema.Value) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: [], got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .union()))
    }
  }

  @Test
  func `Validates Null Value For Null Type`() {
    #expect(throws: Never.self) {
      try validator.validate(value: .null, with: .object(valueSchema: .null))
    }
  }

  @Test(arguments: [JSONSchema.Value.string("blob"), true, 10, [], [:], 10.0])
  func `Invalid When Validating Non-Null Value Against Null Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .null, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .null))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Integer Value Against Integer Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .integer, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .integer()))
    }
  }

  @Test
  func `Validates Integer For Number Type Schema`() {
    #expect(throws: Never.self) {
      try validator.validate(value: 10, with: .object(valueSchema: .number()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:]])
  func `Invalid When Validating Non-Number Value Against Number Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .number, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .number()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Boolean Value Against Boolean Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .boolean, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .boolean))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, [], [:], 10.0])
  func `Invalid When Validating Non-String Value Against String Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .string, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .string()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [:], 10.0])
  func `Invalid When Validating Non-Array Value Against Array Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .array, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .array()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], 10.0])
  func `Invalid When Validating Non-Object Value Against Object Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch(expected: .object, got: value.type)) {
      try validator.validate(value: value, with: .object(valueSchema: .object()))
    }
  }

  @Test
  func `Is Valid When Value Has A Type That Is Part Of The Union`() {
    #expect(throws: Never.self) {
      let schema = JSONSchema.object(
        valueSchema: .union(string: .string(), isBoolean: true, isNullable: true)
      )
      try validator.validate(value: .null, with: schema)
      try validator.validate(value: true, with: schema)
      try validator.validate(value: "hello", with: schema)
    }
  }

  @Test
  func `Invalid When Value Doesn't Match Const`() {
    #expect(
      throws: JSONSchema.ValidationError.constMismatch(expected: "blob", got: "blob jr")
    ) {
      let schema = JSONSchema.object(valueSchema: .string(), const: "blob")
      try validator.validate(value: "blob jr", with: schema)
    }
  }

  @Test
  func `Validates When Value Matches Const`() {
    #expect(throws: Never.self) {
      let schema = JSONSchema.object(valueSchema: .string(), const: "blob")
      try validator.validate(value: "blob", with: schema)
    }
  }

  @Test
  func `Invalid When Value Not Contained In Enum`() {
    #expect(
      throws: JSONSchema.ValidationError.enumMismatch(
        expected: ["blob", "blob jr"],
        got: "blob jr jr"
      )
    ) {
      let schema = JSONSchema.object(valueSchema: .string(), enum: ["blob", "blob jr"])
      try validator.validate(value: "blob jr jr", with: schema)
    }
  }

  @Test
  func `Validates When Value Contained In Enum`() {
    #expect(throws: Never.self) {
      let schema = JSONSchema.object(valueSchema: .string(), enum: ["blob", "blob jr"])
      try validator.validate(value: "blob jr", with: schema)
    }
  }

  @Test
  func `Integer Value Must Be Multiple Of MultipleOf`() {
    let schema = JSONSchema.object(valueSchema: .integer(multipleOf: 2))

    #expect(throws: Never.self) {
      try validator.validate(value: 4, with: schema)
    }
    #expect(throws: JSONSchema.ValidationError.notMultipleOf(integer: 2)) {
      try validator.validate(value: 3, with: schema)
    }
  }

  @Test
  func `Integer Value Must Be Greater Than Or Equal To Inclusive Minimum`() {
    let schema = JSONSchema.object(valueSchema: .integer(minimum: 2))

    #expect(throws: Never.self) {
      try validator.validate(value: 4, with: schema)
    }
    #expect(throws: Never.self) {
      try validator.validate(value: 2, with: schema)
    }
    #expect(throws: JSONSchema.ValidationError.belowMinimum(inclusive: true, integer: 2)) {
      try validator.validate(value: 1, with: schema)
    }
  }
}

private let validator = JSONSchema.Validator()
