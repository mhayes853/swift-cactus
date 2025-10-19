import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchemaValidation tests` {
  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Always Validates For True Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try validator.validate(value: value, with: .boolean(true))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Always Validates For Empty Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try validator.validate(value: value, with: .object(type: nil))
    }
  }

  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Never Validates For False Schema`(value: JSONSchema.Value) {
    #expect(throws: JSONSchema.ValidationError(reason: .falseSchema)) {
      try validator.validate(value: value, with: .boolean(false))
    }
  }

  @Test
  func `Validates Null Value For Null Type`() {
    #expect(throws: Never.self) {
      try validator.validate(value: .null, with: .object(type: .null))
    }
  }
}

private let validator = JSONSchema.Validator()
