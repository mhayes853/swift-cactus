import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `JSONSchemaValueEncoderDecoder tests` {
  @Test
  func `Value Encoder Decodes Primitive Round Trip`() throws {
    let value = PrimitiveContainer(
      string: "blob",
      boolean: true,
      integer: 10,
      number: 10.5,
      nullable: nil
    )
    let decoded = try self.roundTrip(value)
    expectNoDifference(decoded, value)
  }

  @Test
  func `Value Encoder Decodes Nested Round Trip`() throws {
    let value = NestedContainer(
      items: [
        NestedContainer.Item(name: "a", values: [1, 2]),
        NestedContainer.Item(name: "b", values: [3]),
      ]
    )
    let decoded = try self.roundTrip(value)
    expectNoDifference(decoded, value)
  }

  @Test
  func `Value Encoder Decodes Collection Round Trip`() throws {
    let value = CollectionContainer(array: [1, 2, 3], object: ["a": 1, "b": 2])
    let decoded = try self.roundTrip(value)
    expectNoDifference(decoded, value)
  }

  @Test
  func `Value Encoder Decodes Enum Round Trip`() throws {
    let value = EnumContainer(state: .ready)
    let decoded = try self.roundTrip(value)
    expectNoDifference(decoded, value)
  }

  @Test
  func `Value Encoder Decoder UserInfo Is Propagated`() throws {
    let encoder = JSONSchema.Value.Encoder()
    encoder.userInfo[.valueCoderMarker] = "blob"

    let encoded = try encoder.encode(UserInfoEncoderProbe())
    expectNoDifference(encoded, .string("blob"))

    let decoder = JSONSchema.Value.Decoder()
    decoder.userInfo[.valueCoderMarker] = "blob"
    let decoded = try decoder.decode(UserInfoDecoderProbe.self, from: .string("blob"))
    expectNoDifference(decoded.value, "blob")
  }

  @Test
  func `Value Encoder Decoder Foundation Parity Smoke Test`() throws {
    let input = PrimitiveContainer(string: "blob", boolean: true, integer: 1, number: 1.5, nullable: "x")
    let value = try JSONSchema.Value.Encoder().encode(input)
    let fromValueDecoder = try JSONSchema.Value.Decoder().decode(PrimitiveContainer.self, from: value)

    let foundationData = try JSONEncoder().encode(input)
    let fromFoundation = try JSONDecoder().decode(PrimitiveContainer.self, from: foundationData)
    expectNoDifference(fromValueDecoder, fromFoundation)
  }

  @Test
  func `Value Encoder Decoder Matches JSON Encoder Decoder Semantics`() throws {
    let input = CollectionContainer(array: [1, 2, 3], object: ["a": 1, "b": 2])

    let value = try JSONSchema.Value.Encoder().encode(input)
    let foundationData = try JSONEncoder().encode(input)
    let foundationValue = try JSONDecoder().decode(JSONSchema.Value.self, from: foundationData)
    expectNoDifference(value, foundationValue)
  }

  @Test
  func `Value Encoder Decoder Preserves JSONSchema Value Compatibility`() throws {
    let value: JSONSchema.Value = ["name": "blob", "enabled": true, "count": 10]
    let data = try JSONEncoder().encode(value)
    let decodedWithFoundation = try JSONDecoder().decode(JSONSchema.Value.self, from: data)
    expectNoDifference(decodedWithFoundation, value)

    let decodedWithValueDecoder = try JSONSchema.Value.Decoder().decode(JSONSchema.Value.self, from: value)
    expectNoDifference(decodedWithValueDecoder, value)
  }

  private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let encoded = try JSONSchema.Value.Encoder().encode(value)
    return try JSONSchema.Value.Decoder().decode(T.self, from: encoded)
  }
}

private struct PrimitiveContainer: Codable, Equatable {
  let string: String
  let boolean: Bool
  let integer: Int
  let number: Double
  let nullable: String?
}

private struct NestedContainer: Codable, Equatable {
  let items: [Item]

  struct Item: Codable, Equatable {
    let name: String
    let values: [Int]
  }
}

private struct CollectionContainer: Codable, Equatable {
  let array: [Int]
  let object: [String: Int]
}

private struct EnumContainer: Codable, Equatable {
  let state: State

  enum State: String, Codable {
    case ready
    case running
  }
}

private struct UserInfoEncoderProbe: Encodable {
  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(encoder.userInfo[.valueCoderMarker] as? String)
  }
}

private struct UserInfoDecoderProbe: Decodable {
  let value: String

  init(from decoder: any Decoder) throws {
    self.value = decoder.userInfo[.valueCoderMarker] as? String ?? ""
  }
}

extension CodingUserInfoKey {
  fileprivate static let valueCoderMarker = CodingUserInfoKey(rawValue: "valueCoderMarker")!
}
