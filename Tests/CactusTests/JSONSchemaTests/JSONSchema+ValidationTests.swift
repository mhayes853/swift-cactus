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
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .null))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Integer Value Against Integer Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .integer()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, true, "blob", [], [:]])
  func `Invalid When Validating Non-Number Value Against Number Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .number()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], [:], 10.0])
  func `Invalid When Validating Non-Boolean Value Against Boolean Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .boolean))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, [], [:], 10.0])
  func `Invalid When Validating Non-String Value Against String Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .string()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [:], 10.0])
  func `Invalid When Validating Non-Array Value Against Array Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
      try validator.validate(value: value, with: .object(valueSchema: .array()))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, 10, "blob", [], 10.0])
  func `Invalid When Validating Non-Object Value Against Object Schema`(
    value: JSONSchema.Value
  ) {
    #expect(throws: JSONSchema.ValidationError.typeMismatch) {
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
}

private let validator = JSONSchema.Validator()
