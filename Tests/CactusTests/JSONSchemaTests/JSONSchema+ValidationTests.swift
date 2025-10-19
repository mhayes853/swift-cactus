import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchemaValidation tests` {
  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Always Validates For True Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try JSONSchema.boolean(true).validate(value: value)
    }
  }

  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Always Validates For Empty Schema`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try JSONSchema.object(type: nil).validate(value: value)
    }
  }

  @Test(arguments: [JSONSchema.Value.null, "blob", 10, [], [:], 10.0])
  func `Never Validates For False Schema`(value: JSONSchema.Value) {
    #expect(throws: JSONSchema.ValidationError(reason: .falseSchema)) {
      try JSONSchema.boolean(false).validate(value: value)
    }
  }

  @Test
  func `Validates Null Value For Null Type`() {
    #expect(throws: Never.self) {
      try JSONSchema.object(type: .null).validate(value: .null)
    }
  }
}
