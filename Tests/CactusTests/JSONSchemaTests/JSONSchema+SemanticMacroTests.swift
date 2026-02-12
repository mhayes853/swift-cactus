import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchema semantic macro tests` {
  @Test
  func `Semantic Optional Property Generates Nullable Union`() {
    expectNoDifference(
      SemanticPayload.jsonSchema,
      .object(
        valueSchema: .object(
          properties: [
            "name": .string(minLength: 3, maxLength: 10, pattern: "^[a-z]+$"),
            "age": .integer(minimum: 18, maximum: 99),
            "confidence": .union(number: .number(minimum: 0, exclusiveMaximum: 1), null: true)
          ],
          required: ["name", "age"]
        )
      )
    )
  }

  @Test(arguments: [
    ["name": "blob", "age": 42, "confidence": 0.7] as JSONSchema.Value,
    ["name": "blob", "age": 42] as JSONSchema.Value,
    ["name": "blob", "age": 42, "confidence": .null] as JSONSchema.Value
  ])
  func `Semantic Macros Validate Expected Valid Values`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: SemanticPayload.jsonSchema)
    }
  }

  @Test(arguments: [
    (
      ["name": "ab", "age": 42] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.stringLengthTooShort(minimum: 3),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "name")]
    ),
    (
      ["name": "blob", "age": 17] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.belowMinimum(inclusive: true, integer: 18),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "age")]
    ),
    (
      ["name": "blob", "age": 42, "confidence": 1.0] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.aboveMaximum(inclusive: false, number: 1),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "confidence")]
    )
  ])
  func `Semantic Macros Validate Expected Invalid Values`(
    value: JSONSchema.Value,
    reason: JSONSchema.ValidationError.Reason,
    path: [JSONSchema.ValidationError.PathElement]
  ) {
    do {
      try JSONSchema.Validator.shared.validate(value: value, with: SemanticPayload.jsonSchema)
      Issue.record("Value should not validate for schema.")
    } catch {
      expectNoDifference(
        error.failures.contains { $0.path == path && $0.reason == reason },
        true
      )
    }
  }
}

@JSONSchema
private struct SemanticPayload: Codable {
  @JSONStringSchema(minLength: 3, maxLength: 10, pattern: "^[a-z]+$")
  var name: String

  @JSONIntegerSchema(minimum: 18, maximum: 99)
  var age: Int

  @JSONNumberSchema(minimum: 0, exclusiveMaximum: 1)
  var confidence: Double?
}
