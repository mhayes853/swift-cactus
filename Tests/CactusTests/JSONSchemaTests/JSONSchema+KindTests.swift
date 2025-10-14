import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `JSONSchemaKind tests` {
  @Test(
    arguments: [
      (JSONSchema.Kind.number, "\"number\""),
      (.string, "\"string\""),
      (.boolean, "\"boolean\""),
      (.null, "\"null\""),
      (.array, "\"array\""),
      (.object, "\"object\""),
      (.union([.string, .number]), "[\"string\",\"number\"]")
    ]
  )
  func `Schema Kind JSON`(value: JSONSchema.Kind, json: String) throws {
    let data = try JSONEncoder().encode(value)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)
    expectNoDifference(value, try JSONDecoder().decode(JSONSchema.Kind.self, from: data))
  }
}
