import Foundation

struct RegularExpression {
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
}
