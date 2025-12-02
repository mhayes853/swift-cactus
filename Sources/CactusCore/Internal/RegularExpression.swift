import Foundation

// NB: Our usage of Regex doesn't have any non-Sendable transformations, so @unchecked Sendable is safe.
struct RegularExpression: @unchecked Sendable {
  private let inner: Any

  init(_ string: String) throws {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      self.inner = try Regex(string)
    } else {
      self.inner = try NSRegularExpression(pattern: string)
    }
  }

  func matches(_ string: String) -> Bool {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      return string.firstMatch(of: (self.inner as! Regex<AnyRegexOutput>)) != nil
    } else {
      guard let range = NSRange(string) else { return false }
      return !(self.inner as! NSRegularExpression).matches(in: string, range: range).isEmpty
    }
  }

  func matchGroups(from string: String) -> [Substring] {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      return string.matches(of: (self.inner as! Regex<AnyRegexOutput>))
        .flatMap { match in match.output.dropFirst().compactMap(\.substring) }
    } else {
      guard let range = NSRange(string) else { return [] }
      return (self.inner as! NSRegularExpression)
        .matches(in: string, range: range)
        .flatMap { result in
          (1..<result.numberOfRanges)
            .compactMap { idx in
              Range(result.range(at: idx), in: string).map { string[$0] }
            }
        }
    }
  }
}
