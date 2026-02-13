import Cactus
import CustomDump
import StreamParsing
import Testing

@Suite
struct `JSONStreamGenerable tests` {
  @Test
  func `Init From Partial Encodes Validates And Decodes`() throws {
    let partial = User.Partial(name: "Blob", age: 42)
    let user = try User(from: partial)
    expectNoDifference(user, User(name: "Blob", age: 42))
  }

  @Test
  func `Init From Partial With Default Arguments`() throws {
    let partial = User.Partial(name: "Blob", age: 42)
    let user = try User(from: partial)
    expectNoDifference(user, User(name: "Blob", age: 42))
  }

  @Test
  func `Init From Partial Throws Validation Error When Required Property Is Missing`() {
    let partial = User.Partial(name: nil, age: 42)

    #expect(throws: JSONSchema.ValidationError.self) {
      try User(from: partial)
    }
  }
}

@StreamParseable
@JSONSchema
private struct User: Equatable, Codable {
  var name: String
  var age: Int
}

extension User.Partial: Encodable {}
