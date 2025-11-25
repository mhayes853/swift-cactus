import Foundation

struct PromptContentEncoder: Sendable {
  @TaskLocal static var current = Self(JSONEncoder())

  private let encoder: @Sendable () -> sending any TopLevelEncoder<Data>

  init(_ encoder: @escaping @autoclosure @Sendable () -> sending any TopLevelEncoder<Data>) {
    self.encoder = encoder
  }

  func encode(_ value: JSONValue) throws -> Data {
    try self.encoder().encode(value)
  }
}
