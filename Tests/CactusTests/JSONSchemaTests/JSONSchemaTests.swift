import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

@Suite
struct `JSONSchema tests` {
  @Test(
    arguments: [
      (JSONSchema.Value.number(11.1), "11.1"),
      (JSONSchema.Value.integer(1), "1"),
      (.string("blob"), "\"blob\""),
      (.boolean(true), "true"),
      (.null, "null"),
      (.array([.string("blob"), .number(11.1)]), "[\"blob\",11.1]"),
      (.array([]), "[]"),
      (.object([:]), "{}"),
      (.object(["key": .string("value")]), "{\"key\":\"value\"}")
    ]
  )
  func `Schema Value JSON`(value: JSONSchema.Value, json: String) throws {
    let data = try Self.jsonEncoder.encode(value)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.Value.self, from: data)
    expectNoDifference(value, decodedValue)
  }

  @Test(
    arguments: [
      (
        JSONSchema.ValueType.Array.Items.schemaForAll(
          .object(JSONSchema.Object(type: .null))
        ),
        "{\"type\":\"null\"}"
      ),
      (
        JSONSchema.ValueType.Array.Items.itemsSchemas(
          [.object(JSONSchema.Object(type: .null)), .object(JSONSchema.Object(type: .boolean))]
        ),
        "[{\"type\":\"null\"},{\"type\":\"boolean\"}]"
      )
    ]
  )
  func `Array Type Items JSON`(items: JSONSchema.ValueType.Array.Items, json: String) throws {
    let data = try Self.jsonEncoder.encode(items)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.ValueType.Array.Items.self, from: data)
    expectNoDifference(items, decodedValue)
  }

  @Test
  func `Union Type JSON`() throws {
    let value = JSONSchema.object(
      type: .union(string: JSONSchema.ValueType.String(minLength: 10), isBoolean: true)
    )
    let json = "{\"minLength\":10,\"type\":[\"string\",\"boolean\"]}"

    let data = try Self.jsonEncoder.encode(value)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.self, from: data)
    expectNoDifference(value, decodedValue)
  }

  @Test
  func `Boolean Schema JSON`() throws {
    let schema = JSONSchema.boolean(true)
    let json = "true"

    let data = try Self.jsonEncoder.encode(schema)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.self, from: data)
    expectNoDifference(schema, decodedValue)
  }

  @Test
  func `Empty Schema JSON`() throws {
    let schema = JSONSchema.object(type: nil)
    let json = "{}"

    let data = try Self.jsonEncoder.encode(schema)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.self, from: data)
    expectNoDifference(schema, decodedValue)
  }

  @Test(
    .serialized,
    arguments: [
      JSONSchema.Object(
        title: "blob",
        description: "A mysterious loreful character.",
        type: .object(properties: ["name": .object(type: .string())])
      ),
      JSONSchema.Object(
        title: "n",
        description: "A number.",
        type: .number(minimum: 10.1, maximum: 20.2)
      ),
      JSONSchema.Object(title: "b", description: "A boolean.", type: .boolean),
      JSONSchema.Object(title: "Nullable", description: "A nullable property.", type: .null),
      JSONSchema.Object(
        title: "Array",
        description: "An array",
        type: .array(
          items: .schemaForAll(.object(type: .string())),
          minItems: 10,
          uniqueItems: true
        )
      ),
      JSONSchema.Object(title: "Enum", type: nil, enum: [.boolean(true), .string("blob")]),
      JSONSchema.Object(
        title: "Union",
        type: .union(string: JSONSchema.ValueType.String(), isBoolean: true)
      ),
      JSONSchema.Object(
        title: "Integer",
        description: "An integer",
        type: .integer(minimum: 10, maximum: 20)
      )
    ]
  )
  func `Object Schema JSON`(object: JSONSchema.Object) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    assertSnapshot(of: JSONSchema.object(object), as: .json(encoder))
    let decoded = try JSONDecoder()
      .decode(JSONSchema.self, from: Self.jsonEncoder.encode(JSONSchema.object(object)))
    expectNoDifference(decoded, JSONSchema.object(object))
  }

  @Test
  func `Prioritizes Number Properties Over Integer Properties When Encoding`() throws {
    let schema = JSONSchema.object(
      type: .union(
        number: JSONSchema.ValueType.Number(minimum: 10),
        integer: JSONSchema.ValueType.Integer(minimum: 12)
      )
    )
    let data = try Self.jsonEncoder.encode(schema)
    let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)

    switch (schema, decoded) {
    case (.object(let schema), .object(let decoded)):
      expectNoDifference(schema.type?.number?.minimum, decoded.type?.number?.minimum)
      expectNoDifference(decoded.type?.number?.minimum, 10)
      expectNoDifference(decoded.type?.integer?.minimum, 10)
    default:
      break
    }
  }

  private static let jsonEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return encoder
  }()
}
