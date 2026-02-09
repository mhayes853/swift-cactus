import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `JSONSchemaValueDecoder tests` {
  @Test
  func `Value Decoder Decodes String`() throws {
    try self.expectDecodes(String.self, from: .string("blob"), expected: "blob")
  }

  @Test
  func `Value Decoder Decodes Boolean`() throws {
    try self.expectDecodes(Bool.self, from: .boolean(true), expected: true)
  }

  @Test
  func `Value Decoder Decodes Null`() throws {
    try self.expectDecodes(String?.self, from: .null, expected: nil)
  }

  @Test
  func `Value Decoder Decodes Array`() throws {
    try self.expectDecodes([Int].self, from: .array([1, 2, 3]), expected: [1, 2, 3])
  }

  @Test
  func `Value Decoder Decodes Object`() throws {
    try self.expectDecodes(Person.self, from: ["name": "blob", "age": 10], expected: Person(name: "blob", age: 10))
  }

  @Test
  func `Value Decoder Decodes Empty Array`() throws {
    try self.expectDecodes([Int].self, from: .array([]), expected: [])
  }

  @Test
  func `Value Decoder Decodes Empty Object`() throws {
    try self.expectDecodes(Empty.self, from: .object([:]), expected: Empty())
  }

  @Test
  func `Value Decoder Decodes Integral Number Into Integer`() throws {
    try self.expectDecodes(Int.self, from: .number(3.0), expected: 3)
  }

  @Test
  func `Value Decoder Throws For Fractional Number Into Integer`() throws {
    #expect(throws: Error.self) {
      _ = try JSONSchema.Value.Decoder().decode(Int.self, from: .number(3.14))
    }
  }

  @Test
  func `Value Decoder Decodes Integer Into Double`() throws {
    try self.expectDecodes(Double.self, from: .integer(3), expected: 3.0)
  }

  @Test
  func `Value Decoder Throws For Integer Overflow`() throws {
    #expect(throws: Error.self) {
      _ = try JSONSchema.Value.Decoder().decode(Int8.self, from: .integer(999))
    }
  }

  @Test
  func `Value Decoder Distinguishes Missing Key And Null`() throws {
    try self.expectDecodes(OptionalKeyContainer.self, from: .object([:]), expected: OptionalKeyContainer(value: nil))
    try self.expectDecodes(OptionalKeyContainer.self, from: .object(["value": .null]), expected: OptionalKeyContainer(value: nil))
  }

  @Test
  func `Value Decoder Throws For Missing Required Key`() throws {
    #expect(throws: Error.self) {
      _ = try JSONSchema.Value.Decoder().decode(RequiredKeyContainer.self, from: .object([:]))
    }
  }

  @Test
  func `Value Decoder Decodes Nested Optional Containers`() throws {
    let value: JSONSchema.Value = ["items": [.object(["value": .integer(1)]), .object(["value": .null])]]
    let expected = NestedOptionalContainer(items: [OptionalValue(value: 1), OptionalValue(value: nil)])
    try self.expectDecodes(NestedOptionalContainer.self, from: value, expected: expected)
  }

  @Test
  func `Value Decoder Single Value Container Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(SingleValueInt.self, from: .string("oops"))
    }
    guard case let .typeMismatch(_, context)? = error else {
      Issue.record("Expected typeMismatch, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.codingPath.isEmpty, true)
  }

  @Test
  func `Value Decoder Unkeyed Container Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode([Int].self, from: .array([.integer(1), .string("oops")]))
    }
    guard case let .typeMismatch(_, context)? = error else {
      Issue.record("Expected typeMismatch, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.codingPath.last?.intValue, 1)
  }

  @Test
  func `Value Decoder Keyed Container Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(Person.self, from: ["name": "blob", "age": "oops"])
    }
    guard case let .typeMismatch(_, context)? = error else {
      Issue.record("Expected typeMismatch, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.codingPath.last?.stringValue, "age")
  }

  @Test
  func `Value Decoder Date Strategy Deferred To Date`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .deferredToDate
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .deferredToDate
    }
  }

  @Test
  func `Value Decoder Date Strategy Seconds Since 1970`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .secondsSince1970
    } encoder: { encoder in
      encoder.dateEncodingStrategy = .secondsSince1970
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .secondsSince1970
    }
  }

  @Test
  func `Value Decoder Date Strategy Milliseconds Since 1970`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .millisecondsSince1970
    } encoder: { encoder in
      encoder.dateEncodingStrategy = .millisecondsSince1970
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .millisecondsSince1970
    }
  }

  @Test
  func `Value Decoder Date Strategy ISO8601`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .iso8601
    } encoder: { encoder in
      encoder.dateEncodingStrategy = .iso8601
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .iso8601
    }
  }

  @Test
  func `Value Decoder Date Strategy Formatted`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .formatted(formatter)
    } encoder: { encoder in
      encoder.dateEncodingStrategy = .formatted(formatter)
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .formatted(formatter)
    }
  }

  @Test
  func `Value Decoder Date Strategy Custom`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let value = try self.foundationValue(DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let timestamp = Double(string.replacingOccurrences(of: "d:", with: ""))!
        return Date(timeIntervalSince1970: timestamp)
      }
    } encoder: { encoder in
      encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("d:\(Int(date.timeIntervalSince1970))")
      }
    }
    try self.expectDecodes(DateBox.self, from: value, expected: DateBox(date: date)) { decoder in
      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let timestamp = Double(string.replacingOccurrences(of: "d:", with: ""))!
        return Date(timeIntervalSince1970: timestamp)
      }
    }
  }

  @Test
  func `Value Decoder Data Strategy Deferred To Data`() throws {
    let expected = DataBox(data: Data([1, 2, 3]))
    let value = try self.foundationValue(expected) { decoder in
      decoder.dataDecodingStrategy = .deferredToData
    } encoder: { encoder in
      encoder.dataEncodingStrategy = .deferredToData
    }
    try self.expectDecodes(DataBox.self, from: value, expected: expected) { decoder in
      decoder.dataDecodingStrategy = .deferredToData
    }
  }

  @Test
  func `Value Decoder Data Strategy Base64`() throws {
    let expected = DataBox(data: Data([1, 2, 3]))
    let value = try self.foundationValue(expected) { decoder in
      decoder.dataDecodingStrategy = .base64
    }
    try self.expectDecodes(DataBox.self, from: value, expected: expected) { decoder in
      decoder.dataDecodingStrategy = .base64
    }
  }

  @Test
  func `Value Decoder Data Strategy Custom`() throws {
    let expected = DataBox(data: Data([1, 2, 3]))
    let value = try self.foundationValue(expected) { decoder in
      decoder.dataDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let count = Int(string.replacingOccurrences(of: "bytes:", with: ""))!
        return Data(repeating: 1, count: count)
      }
    } encoder: { encoder in
      encoder.dataEncodingStrategy = .custom { data, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("bytes:\(data.count)")
      }
    }
    try self.expectDecodes(DataBox.self, from: value, expected: DataBox(data: Data(repeating: 1, count: 3))) { decoder in
      decoder.dataDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let count = Int(string.replacingOccurrences(of: "bytes:", with: ""))!
        return Data(repeating: 1, count: count)
      }
    }
  }

  @Test
  func `Value Decoder Non Conforming Float Strategy Throw`() throws {
    let value: JSONSchema.Value = ["value": "NaN"]
    let decoder = JSONSchema.Value.Decoder()
    decoder.nonConformingFloatDecodingStrategy = .throw

    #expect(throws: Error.self) {
      _ = try decoder.decode(DoubleContainer.self, from: value)
    }
  }

  @Test
  func `Value Decoder Non Conforming Float Strategy Convert From String`() throws {
    let value: JSONSchema.Value = ["value": "NaN"]
    try self.expectDecodes(DoubleContainer.self, from: value, expected: DoubleContainer(value: .nan)) { decoder in
      decoder.nonConformingFloatDecodingStrategy =
        .convertFromString(positiveInfinity: "+INF", negativeInfinity: "-INF", nan: "NaN")
    }
  }

  @Test
  func `Value Decoder Key Decoding Strategy Use Default Keys`() throws {
    try self.expectDecodes(SnakeCaseContainer.self, from: ["someValue": 1], expected: SnakeCaseContainer(someValue: 1)) { decoder in
      decoder.keyDecodingStrategy = .useDefaultKeys
    }
  }

  @Test
  func `Value Decoder Key Decoding Strategy Convert From Snake Case`() throws {
    try self.expectDecodes(SnakeCaseContainer.self, from: ["some_value": 1], expected: SnakeCaseContainer(someValue: 1)) { decoder in
      decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
  }

  @Test(
    arguments: [
      ("", ""),
      ("a", "a"),
      ("ALLCAPS", "ALLCAPS"),
      ("ALL_CAPS", "allCaps"),
      ("single", "single"),
      ("snake_case", "snakeCase"),
      ("one_two_three", "oneTwoThree"),
      ("one_2_three", "one2Three"),
      ("one2_three", "one2Three"),
      ("alreadyCamelCase", "alreadyCamelCase"),
      ("__this_and_that", "__thisAndThat"),
      ("_this_and_that", "_thisAndThat"),
      ("this__and__that", "thisAndThat"),
      ("this_and_that__", "thisAndThat__"),
      ("_one_two_three", "_oneTwoThree"),
      ("one_two_three_", "oneTwoThree_"),
      ("__one_two_three", "__oneTwoThree"),
      ("one_two_three__", "oneTwoThree__"),
      ("_one_two_three_", "_oneTwoThree_"),
      ("__one_two_three__", "__oneTwoThree__"),
      ("_", "_"),
      ("__", "__"),
      ("___", "___")
    ]
  )
  func `Value Decoder Key Decoding Strategy Convert From Snake Case Cases`(
    input: String,
    expectedKey: String
  ) throws {
    let payload: JSONSchema.Value = .object(["camelCaseKey": .string(expectedKey), input: .boolean(true)])
    let decoder = JSONSchema.Value.Decoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(ConvertFromSnakeProbe.self, from: payload)
    expectNoDifference(result.found, true)
  }

  @Test
  func `Value Decoder Key Decoding Strategy Custom`() throws {
    try self.expectDecodes(SnakeCaseContainer.self, from: ["x_someValue": 1], expected: SnakeCaseContainer(someValue: 1)) { decoder in
      decoder.keyDecodingStrategy = .custom { codingPath in
        let key = codingPath.last!.stringValue.replacingOccurrences(of: "x_", with: "")
        return AnyCodingKey(stringValue: key)
      }
    }
  }

  @Test
  func `Value Decoder Type Mismatch Includes Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(Person.self, from: ["name": "blob", "age": "oops"])
    }
    guard case let .typeMismatch(_, context)? = error else {
      Issue.record("Expected typeMismatch, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.codingPath.last?.stringValue, "age")
  }

  @Test
  func `Value Decoder Key Not Found Includes Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(Person.self, from: ["name": "blob"])
    }
    guard case let .keyNotFound(key, context)? = error else {
      Issue.record("Expected keyNotFound, got \(String(describing: error)).")
      return
    }
    expectNoDifference(key.stringValue, "age")
    expectNoDifference(context.codingPath.last?.stringValue, "age")
  }

  @Test
  func `Value Decoder Value Not Found Includes Coding Path`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(NonOptionalString.self, from: ["value": .null])
    }
    guard case let .valueNotFound(_, context)? = error else {
      Issue.record("Expected valueNotFound, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.codingPath.last?.stringValue, "value")
  }

  @Test
  func `Value Decoder Data Corrupted Includes Debug Description`() throws {
    let error = #expect(throws: DecodingError.self) {
      _ = try JSONSchema.Value.Decoder().decode(URL.self, from: .string("not a URL"))
    }
    guard case let .dataCorrupted(context)? = error else {
      Issue.record("Expected dataCorrupted, got \(String(describing: error)).")
      return
    }
    expectNoDifference(context.debugDescription.isEmpty, false)
  }

  private func expectDecodes<T: Decodable & Equatable>(
    _ type: T.Type,
    from value: JSONSchema.Value,
    expected: T,
    configure: (JSONSchema.Value.Decoder) -> Void = { _ in }
  ) throws {
    let decoder = JSONSchema.Value.Decoder()
    configure(decoder)
    let actual = try decoder.decode(type, from: value)
    expectNoDifference(actual, expected)
  }

  private func foundationValue<T: Codable>(
    _ input: T,
    configure: (JSONDecoder) -> Void,
    encoder configureEncoder: (JSONEncoder) -> Void = { _ in }
  ) throws -> JSONSchema.Value {
    let encoder = JSONEncoder()
    configureEncoder(encoder)
    let data = try encoder.encode(input)
    let decoder = JSONDecoder()
    configure(decoder)
    _ = decoder
    return try JSONDecoder().decode(JSONSchema.Value.self, from: data)
  }
}

private struct Person: Codable, Equatable {
  let name: String
  let age: Int
}

private struct Empty: Codable, Equatable {}

private struct OptionalKeyContainer: Codable, Equatable {
  let value: String?
}

private struct RequiredKeyContainer: Codable, Equatable {
  let value: String
}

private struct OptionalValue: Codable, Equatable {
  let value: Int?
}

private struct NestedOptionalContainer: Codable, Equatable {
  let items: [OptionalValue]
}

private struct SingleValueInt: Codable, Equatable {
  let value: Int

  init(value: Int) {
    self.value = value
  }

  init(from decoder: any Swift.Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.value = try container.decode(Int.self)
  }

  func encode(to encoder: any Swift.Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.value)
  }
}

private struct DateBox: Codable, Equatable {
  let date: Date
}

private struct DataBox: Codable, Equatable {
  let data: Data
}

private struct DoubleContainer: Codable, Equatable {
  let value: Double

  static func == (lhs: DoubleContainer, rhs: DoubleContainer) -> Bool {
    lhs.value.isNaN && rhs.value.isNaN || lhs.value == rhs.value
  }
}

private struct SnakeCaseContainer: Codable, Equatable {
  let someValue: Int
}

private struct ConvertFromSnakeProbe: Decodable {
  let found: Bool

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    let camelCaseKey = try container.decode(String.self, forKey: AnyCodingKey(stringValue: "camelCaseKey"))
    self.found = try container.decode(Bool.self, forKey: AnyCodingKey(stringValue: camelCaseKey))
  }
}

private struct NonOptionalString: Codable, Equatable {
  let value: String
}

private struct AnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
