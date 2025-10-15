import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `JSONSchema+Value tests` {
  @Test(
    arguments: [
      (JSONSchema.Value.number(1), "1"),
      (.string("blob"), "\"blob\""),
      (.boolean(true), "true"),
      (.null, "null"),
      (.array([.string("blob"), .number(1)]), "[\"blob\",1]"),
      (.array([]), "[]"),
      (.object([:]), "{}"),
      (.object(["key": .string("value")]), "{\"key\":\"value\"}")
    ]
  )
  func `Schema Value JSON`(value: JSONSchema.Value, json: String) throws {
    let data = try JSONEncoder().encode(value)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(JSONSchema.Value.self, from: data)
    expectNoDifference(value, decodedValue)
  }

}
