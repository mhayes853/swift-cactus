import Cactus
import CustomDump
import Testing

@Suite
struct `JSONGenerable tests` {
  @Test
  func `Decodes Valid JSON Value`() throws {
    let value: JSONSchema.Value = [
      "name": "Blob",
      "age": 42
    ]

    let person = try Person(jsonValue: value)

    expectNoDifference(person, Person(name: "Blob", age: 42, nickname: nil))
  }

  @Test
  func `Throws Validation Error For Missing Required Property`() {
    let value: JSONSchema.Value = [
      "name": "Blob"
    ]

    #expect(throws: JSONSchema.ValidationError.self) {
      try Person(jsonValue: value)
    }
  }

  @Test
  func `Uses Custom Decoder Strategy`() throws {
    let value: JSONSchema.Value = [
      "first_name": "Blob",
      "age": 42
    ]

    let decoder = JSONSchema.Value.Decoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let user = try SnakeCaseUser(
      jsonValue: value,
      validator: .shared,
      decoder: decoder
    )

    expectNoDifference(user, SnakeCaseUser(firstName: "Blob", age: 42))
  }

  @Test
  func `Macro Generated Conformance Decodes JSON Value`() throws {
    let value: JSONSchema.Value = [
      "name": "Blob"
    ]

    let user = try MacroUser(jsonValue: value)

    expectNoDifference(user, MacroUser(name: "Blob"))
  }
}

private struct Person: Equatable, JSONGenerable {
  var name: String
  var age: Int
  var nickname: String?

  static var jsonSchema: JSONSchema {
    .object(
      valueSchema: .object(
        properties: [
          "name": String.jsonSchema,
          "age": Int.jsonSchema,
          "nickname": String?.jsonSchema
        ],
        required: ["name", "age"]
      )
    )
  }
}

private struct SnakeCaseUser: Equatable, JSONGenerable {
  var firstName: String
  var age: Int

  static var jsonSchema: JSONSchema {
    .object(
      valueSchema: .object(
        properties: [
          "first_name": String.jsonSchema,
          "age": Int.jsonSchema
        ],
        required: ["first_name", "age"]
      )
    )
  }
}

@JSONSchema
private struct MacroUser: Equatable, Codable {
  var name: String
}
