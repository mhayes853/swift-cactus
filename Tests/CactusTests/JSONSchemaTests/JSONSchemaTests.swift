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
      (1, "1"),
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
        JSONSchema.ValueSchema.Array.Items.schemaForAll(.object(valueSchema: .null)),
        "{\"type\":\"null\"}"
      ),
      (
        JSONSchema.ValueSchema.Array.Items.itemsSchemas(
          [.object(valueSchema: .null), .object(valueSchema: .boolean)]
        ),
        "[{\"type\":\"null\"},{\"type\":\"boolean\"}]"
      )
    ]
  )
  func `Array Type Items JSON`(items: JSONSchema.ValueSchema.Array.Items, json: String) throws {
    let data = try Self.jsonEncoder.encode(items)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.ValueSchema.Array.Items.self, from: data)
    expectNoDifference(items, decodedValue)
  }

  @Test
  func `Union Type JSON`() throws {
    let value = JSONSchema.object(
      valueSchema: .union(string: .string(minLength: 10), isBoolean: true)
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
    let schema = JSONSchema.object(valueSchema: nil)
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
        valueSchema: .object(properties: ["name": .object(valueSchema: .string())])
      ),
      JSONSchema.Object(
        title: "n",
        description: "A number.",
        valueSchema: .number(minimum: 10.1, maximum: 20.2)
      ),
      JSONSchema.Object(title: "b", description: "A boolean.", valueSchema: .boolean),
      JSONSchema.Object(title: "Nullable", description: "A nullable property.", valueSchema: .null),
      JSONSchema.Object(
        title: "Array",
        description: "An array",
        valueSchema: .array(
          items: .schemaForAll(.object(valueSchema: .string())),
          minItems: 10,
          uniqueItems: true
        )
      ),
      JSONSchema.Object(title: "Enum", valueSchema: nil, enum: [.boolean(true), .string("blob")]),
      JSONSchema.Object(title: "Union", valueSchema: .union(string: .string(), isBoolean: true)),
      JSONSchema.Object(
        title: "Integer",
        description: "An integer",
        valueSchema: .integer(minimum: 10, maximum: 20)
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
      valueSchema: .union(number: .number(minimum: 10), integer: .integer(minimum: 12))
    )
    let data = try Self.jsonEncoder.encode(schema)
    let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)

    switch (schema, decoded) {
    case (.object(let schema), .object(let decoded)):
      expectNoDifference(schema.valueSchema?.number?.minimum, decoded.valueSchema?.number?.minimum)
      expectNoDifference(decoded.valueSchema?.number?.minimum, 10)
      expectNoDifference(decoded.valueSchema?.integer?.minimum, 10)
    default:
      break
    }
  }

  @Test
  func `Nil Value Type When Empty Union ValueSchema`() {
    let schema = JSONSchema.Object(valueSchema: .union())
    expectNoDifference(schema.type, nil)
  }

  @Test
  func `Single Value Type When Single ValueSchema`() {
    let schema = JSONSchema.Object(valueSchema: .number(minimum: 10))
    expectNoDifference(schema.type, .number)
  }

  @Test
  func `Union Value Type When Union ValueSchema`() {
    let schema = JSONSchema.Object(
      valueSchema: .union(number: .number(minimum: 10), isNullable: true)
    )
    expectNoDifference(schema.type, [.number, .null])
  }

  private static let jsonEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return encoder
  }()
}
