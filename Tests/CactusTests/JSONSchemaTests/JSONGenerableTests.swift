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

private struct Person: Equatable, JSONGenerable, Codable {
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

extension Person: StreamParseableValue {
  typealias Partial = Self

  var streamPartialValue: Self { self }

  static func initialParseableValue() -> Self {
    Self(name: "", age: 0, nickname: nil)
  }

  static func registerHandlers(in handlers: inout some StreamParserHandlers<Self>) {
    handlers.registerKeyedHandler(forKey: "name", \.name)
    handlers.registerKeyedHandler(forKey: "age", \.age)
    handlers.registerKeyedHandler(forKey: "nickname", \.nickname)
  }
}

private struct SnakeCaseUser: Equatable, JSONGenerable, Codable {
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

extension SnakeCaseUser: StreamParseableValue {
  typealias Partial = Self

  var streamPartialValue: Self { self }

  static func initialParseableValue() -> Self {
    Self(firstName: "", age: 0)
  }

  static func registerHandlers(in handlers: inout some StreamParserHandlers<Self>) {
    handlers.registerKeyedHandler(forKey: "firstName", \.firstName)
    handlers.registerKeyedHandler(forKey: "age", \.age)
  }
}

@JSONGenerable
private struct MacroUser: Equatable, Codable {
  var name: String
}
