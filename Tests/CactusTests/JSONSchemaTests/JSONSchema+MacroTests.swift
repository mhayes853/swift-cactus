import Cactus
import CustomDump
import Testing

@Suite
struct `JSONSchemaMacro tests` {
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
    let error = #expect(throws: JSONSchema.ValidationError.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: SemanticPayload.jsonSchema)
    }
    expectNoDifference(
      error?.failures.contains { $0.path == path && $0.reason == reason },
      true
    )
  }

  @Test(arguments: [
    ["tags": ["a"], "counts": [1], "confidences": [0.2, 0.9]] as JSONSchema.Value,
    ["tags": ["a"], "counts": [1]] as JSONSchema.Value,
    ["tags": ["a"], "counts": [1], "confidences": .null] as JSONSchema.Value
  ])
  func `Array Item Semantic Macros Validate Expected Valid Values`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: ArraySemanticPayload.jsonSchema)
    }
  }

  @Test(arguments: [
    (
      ["tags": JSONSchema.Value.array([]), "counts": [1]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.arrayLengthTooShort(minimum: 1),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "tags")]
    ),
    (
      ["tags": ["a"], "counts": [-1]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.belowMinimum(inclusive: true, integer: 0),
      [
        JSONSchema.ValidationError.PathElement.objectValue(property: "counts"),
        JSONSchema.ValidationError.PathElement.arrayItem(index: 0)
      ]
    ),
    (
      ["tags": ["a"], "counts": [1], "confidences": [1.0]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.aboveMaximum(inclusive: false, number: 1),
      [
        JSONSchema.ValidationError.PathElement.objectValue(property: "confidences"),
        JSONSchema.ValidationError.PathElement.arrayItem(index: 0)
      ]
    )
  ])
  func `Array Item Semantic Macros Validate Expected Invalid Values`(
    value: JSONSchema.Value,
    reason: JSONSchema.ValidationError.Reason,
    path: [JSONSchema.ValidationError.PathElement]
  ) {
    let error = #expect(throws: JSONSchema.ValidationError.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: ArraySemanticPayload.jsonSchema)
    }
    expectNoDifference(
      error?.failures.contains { $0.path == path && $0.reason == reason },
      true
    )
  }

  @Test(arguments: [
    ["metadata": ["key": "value"], "tags": ["tag1": "value1"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["a": "1", "b": "2", "c": "3"], "tags": ["tag1": "value1", "tag2": "value2"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["tag1": "value1", "tag2": "value2"], "tags": ["tag1": "value1", "tag2": "value2"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["a": "1", "b": "2"], "tags": ["tag1": "value1"], "counts": ["a": 1, "b": 2], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["a": "1"], "tags": ["tag1": "value1"], "counts": ["a": 1], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["key": "value"], "tags": ["tag1": "value1"], "counts": JSONSchema.Value.null, "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
    ["metadata": ["key": "value"], "tags": ["tag1": "value1"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value
  ])
  func `Object Semantic Macros Validate Expected Valid Values`(value: JSONSchema.Value) {
    #expect(throws: Never.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: JSONObjectSemanticPayload.jsonSchema)
    }
  }

  @Test(arguments: [
    (
      ["metadata": [:] as JSONSchema.Value, "tags": ["tag1": "value1"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.objectPropertiesTooShort(minimum: 1),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "metadata")]
    ),
    (
      ["metadata": ["a": "1", "b": "2", "c": "3", "d": "4"], "tags": ["tag1": "value1"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.objectPropertiesTooLong(maximum: 3),
      [JSONSchema.ValidationError.PathElement.objectValue(property: "metadata")]
    ),
    (
      ["metadata": ["key": "value"], "tags": ["tag1": "ab"], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.stringLengthTooShort(minimum: 3),
      [
        JSONSchema.ValidationError.PathElement.objectValue(property: "tags"),
        JSONSchema.ValidationError.PathElement.objectValue(property: "tag1")
      ]
    ),
    (
      ["metadata": ["key": "value"], "tags": ["tag1": "value1"], "counts": ["a": -1], "validatedMetadata": ["key": "value"]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.belowMinimum(inclusive: true, integer: 0),
      [
        JSONSchema.ValidationError.PathElement.objectValue(property: "counts"),
        JSONSchema.ValidationError.PathElement.objectValue(property: "a")
      ]
    ),
    (
      ["metadata": ["key": "value"], "tags": ["tag1": "value1"], "validatedMetadata": ["key": "ab"]] as JSONSchema.Value,
      JSONSchema.ValidationError.Reason.stringLengthTooShort(minimum: 3),
      [
        JSONSchema.ValidationError.PathElement.objectValue(property: "validatedMetadata"),
        JSONSchema.ValidationError.PathElement.objectValue(property: "key")
      ]
    )
  ])
  func `Object Semantic Macros Validate Expected Invalid Values`(
    value: JSONSchema.Value,
    reason: JSONSchema.ValidationError.Reason,
    path: [JSONSchema.ValidationError.PathElement]
  ) {
    let error = #expect(throws: JSONSchema.ValidationError.self) {
      try JSONSchema.Validator.shared.validate(value: value, with: JSONObjectSemanticPayload.jsonSchema)
    }
    expectNoDifference(
      error?.failures.contains { $0.path == path && $0.reason == reason },
      true
    )
  }
}

@JSONSchema
private struct SemanticPayload: Codable {
  @JSONSchemaProperty(.string(minLength: 3, maxLength: 10, pattern: "^[a-z]+$"))
  var name: String

  @JSONSchemaProperty(.integer(minimum: 18, maximum: 99))
  var age: Int

  @JSONSchemaProperty(.number(minimum: 0, exclusiveMaximum: 1))
  var confidence: Double?
}

@JSONSchema
private struct ArraySemanticPayload: Codable {
  @JSONSchemaProperty(.array(minItems: 1))
  var tags: [String]

  @JSONSchemaProperty(
    .array(items: .schemaForAll(.integer(minimum: 0)), minItems: 1, uniqueItems: true)
  )
  var counts: [Int]

  @JSONSchemaProperty(
    .array(items: .schemaForAll(.number(minimum: 0, exclusiveMaximum: 1)))
  )
  var confidences: [Double]?
}

@JSONSchema
private struct JSONObjectSemanticPayload: Codable {
  @JSONSchemaProperty(.object(minProperties: 1, maxProperties: 3))
  var metadata: [String: String]

  @JSONSchemaProperty(
    .object(minProperties: 1, additionalProperties: .string(minLength: 3))
  )
  var tags: [String: String]

  @JSONSchemaProperty(
    .object(minProperties: 1, additionalProperties: .integer(minimum: 0))
  )
  var counts: [String: Int]?

  @JSONSchemaProperty(.object(additionalProperties: .string(minLength: 3)))
  var validatedMetadata: [String: String]
}
