import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `JSONSchemaValueEncoder tests` {
  @Test
  func `Value Encoder Encodes String`() throws {
    try self.expectEncodes("blob")
  }

  @Test
  func `Value Encoder Encodes Boolean`() throws {
    try self.expectEncodes(true)
  }

  @Test
  func `Value Encoder Encodes Null`() throws {
    let value: String? = nil
    try self.expectEncodes(value)
  }

  @Test
  func `Value Encoder Encodes Array`() throws {
    try self.expectEncodes([1, 2, 3])
  }

  @Test
  func `Value Encoder Encodes Object`() throws {
    try self.expectEncodes(Person(name: "blob", age: 10))
  }

  @Test
  func `Value Encoder Encodes Empty Array`() throws {
    try self.expectEncodes([Int]())
  }

  @Test
  func `Value Encoder Encodes Empty Object`() throws {
    try self.expectEncodes(Empty())
  }

  @Test
  func `Value Encoder Encodes Integer As Integer`() throws {
    let actual = try JSONSchema.Value.Encoder().encode(IntBox(value: 7))
    expectNoDifference(actual, .object(["value": .integer(7)]))
  }

  @Test
  func `Value Encoder Encodes Double As Number`() throws {
    let actual = try JSONSchema.Value.Encoder().encode(DoubleBox(value: 7.5))
    expectNoDifference(actual, .object(["value": .number(7.5)]))
  }

  @Test
  func `Value Encoder Throws For Integer Overflow`() throws {
    #expect(throws: Error.self) {
      _ = try JSONSchema.Value.Encoder().encode(UInt64.max)
    }
  }

  @Test
  func `Value Encoder Date Strategy Deferred To Date`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .deferredToDate
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .deferredToDate
    }
  }

  @Test
  func `Value Encoder Date Strategy Seconds Since 1970`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .secondsSince1970
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .secondsSince1970
    }
  }

  @Test
  func `Value Encoder Date Strategy Milliseconds Since 1970`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .millisecondsSince1970
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .millisecondsSince1970
    }
  }

  @Test
  func `Value Encoder Date Strategy ISO8601`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .iso8601
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .iso8601
    }
  }

  @Test
  func `Value Encoder Date Strategy Formatted`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .formatted(formatter)
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .formatted(formatter)
    }
  }

  @Test
  func `Value Encoder Date Strategy Custom`() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    try self.expectEncodes(DateBox(date: date)) { encoder in
      encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("d:\(Int(date.timeIntervalSince1970))")
      }
    } foundation: { encoder in
      encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("d:\(Int(date.timeIntervalSince1970))")
      }
    }
  }

  @Test
  func `Value Encoder Data Strategy Deferred To Data`() throws {
    try self.expectEncodes(DataBox(data: Data([1, 2, 3]))) { encoder in
      encoder.dataEncodingStrategy = .deferredToData
    } foundation: { encoder in
      encoder.dataEncodingStrategy = .deferredToData
    }
  }

  @Test
  func `Value Encoder Data Strategy Base64`() throws {
    try self.expectEncodes(DataBox(data: Data([1, 2, 3]))) { encoder in
      encoder.dataEncodingStrategy = .base64
    } foundation: { encoder in
      encoder.dataEncodingStrategy = .base64
    }
  }

  @Test
  func `Value Encoder Data Strategy Custom`() throws {
    try self.expectEncodes(DataBox(data: Data([1, 2, 3]))) { encoder in
      encoder.dataEncodingStrategy = .custom { data, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("bytes:\(data.count)")
      }
    } foundation: { encoder in
      encoder.dataEncodingStrategy = .custom { data, encoder in
        var container = encoder.singleValueContainer()
        try container.encode("bytes:\(data.count)")
      }
    }
  }

  @Test
  func `Value Encoder Non Conforming Float Strategy Throw`() throws {
    let encoder = JSONSchema.Value.Encoder()
    encoder.nonConformingFloatEncodingStrategy = .throw

    #expect(throws: Error.self) {
      _ = try encoder.encode(DoubleBox(value: .nan))
    }
  }

  @Test
  func `Value Encoder Non Conforming Float Strategy Convert To String`() throws {
    try self.expectEncodes(DoubleBox(value: .infinity)) { encoder in
      encoder.nonConformingFloatEncodingStrategy =
        .convertToString(positiveInfinity: "+INF", negativeInfinity: "-INF", nan: "NaN")
    } foundation: { encoder in
      encoder.nonConformingFloatEncodingStrategy =
        .convertToString(positiveInfinity: "+INF", negativeInfinity: "-INF", nan: "NaN")
    }
  }

  @Test
  func `Value Encoder Key Encoding Strategy Use Default Keys`() throws {
    try self.expectEncodes(SnakeCaseBox(someValue: 1)) { encoder in
      encoder.keyEncodingStrategy = .useDefaultKeys
    } foundation: { encoder in
      encoder.keyEncodingStrategy = .useDefaultKeys
    }
  }

  @Test
  func `Value Encoder Key Encoding Strategy Convert To Snake Case`() throws {
    try self.expectEncodes(SnakeCaseBox(someValue: 1)) { encoder in
      encoder.keyEncodingStrategy = .convertToSnakeCase
    } foundation: { encoder in
      encoder.keyEncodingStrategy = .convertToSnakeCase
    }
  }

  @Test(
    arguments: [
      ("simpleOneTwo", "simple_one_two"),
      ("myURL", "my_url"),
      ("singleCharacterAtEndX", "single_character_at_end_x"),
      ("thisIsAnXMLProperty", "this_is_an_xml_property"),
      ("single", "single"),
      ("", ""),
      ("a", "a"),
      ("aA", "a_a"),
      ("version4Thing", "version4_thing"),
      ("partCAPS", "part_caps"),
      ("partCAPSLowerAGAIN", "part_caps_lower_again"),
      ("manyWordsInThisThing", "many_words_in_this_thing"),
      ("already_snake_case", "already_snake_case"),
      ("dataPoint22", "data_point22"),
      ("dataPoint22Word", "data_point22_word"),
      ("_oneTwoThree", "_one_two_three"),
      ("oneTwoThree_", "one_two_three_"),
      ("__oneTwoThree", "__one_two_three"),
      ("oneTwoThree__", "one_two_three__"),
      ("_oneTwoThree_", "_one_two_three_")
    ]
  )
  func `Value Encoder Key Encoding Strategy Convert To Snake Case Cases`(
    input: String,
    expectedKey: String
  ) throws {
    let encoded = try JSONSchema.Value.Encoder().with { encoder in
      encoder.keyEncodingStrategy = .convertToSnakeCase
      return try encoder.encode(DynamicKeyValue(keyName: input, value: "test"))
    }
    expectNoDifference(encoded, .object([expectedKey: .string("test")]))
  }

  @Test
  func `Value Encoder Key Encoding Strategy Custom`() throws {
    try self.expectEncodes(SnakeCaseBox(someValue: 1)) { encoder in
      encoder.keyEncodingStrategy = .custom { codingPath in
        AnyCodingKey(stringValue: "x_\(codingPath.last!.stringValue)")
      }
    } foundation: { encoder in
      encoder.keyEncodingStrategy = .custom { codingPath in
        AnyCodingKey(stringValue: "x_\(codingPath.last!.stringValue)")
      }
    }
  }

  private func expectEncodes<T: Encodable>(
    _ input: T,
    configure: (JSONSchema.Value.Encoder) -> Void = { _ in },
    foundation: (JSONEncoder) -> Void = { _ in }
  ) throws {
    let encoder = JSONSchema.Value.Encoder()
    configure(encoder)
    let actual = try encoder.encode(input)
    let expected = try self.foundationValue(input, configure: foundation)
    expectNoDifference(actual, expected)
  }

  private func foundationValue<T: Encodable>(
    _ input: T,
    configure: (JSONEncoder) -> Void
  ) throws -> JSONSchema.Value {
    let encoder = JSONEncoder()
    configure(encoder)
    let data = try encoder.encode(input)
    return try JSONDecoder().decode(JSONSchema.Value.self, from: data)
  }
}

private struct Person: Codable, Equatable {
  let name: String
  let age: Int
}

private struct Empty: Codable, Equatable {}

private struct IntBox: Codable, Equatable {
  let value: Int
}

private struct DoubleBox: Codable, Equatable {
  let value: Double
}

private struct DateBox: Codable, Equatable {
  let date: Date
}

private struct DataBox: Codable, Equatable {
  let data: Data
}

private struct SnakeCaseBox: Codable, Equatable {
  let someValue: Int
}

private struct DynamicKeyValue: Encodable {
  let keyName: String
  let value: String

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: AnyCodingKey.self)
    try container.encode(self.value, forKey: AnyCodingKey(stringValue: self.keyName))
  }
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

extension JSONSchema.Value.Encoder {
  fileprivate func with<T>(_ body: (JSONSchema.Value.Encoder) throws -> T) rethrows -> T {
    try body(self)
  }
}
