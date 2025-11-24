import Foundation

public struct CactusPromptContent: Sendable {
  public var imageURLs: [URL] { [] }

  public init(_ content: some CactusPromptRepresentable) {

  }

  public init<E: Error>(
    @CactusPromptBuilder build: () throws(E) -> some CactusPromptRepresentable
  ) throws(E) {

  }
}

extension CactusPromptContent: CustomStringConvertible {
  public var description: String {
    ""
  }
}

extension CactusPromptContent: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
  }
}
