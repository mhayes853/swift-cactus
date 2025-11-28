import SwiftSyntax

extension TypeSyntax {
  var isOptional: Bool {
    self.description.contains("?")
      || self.description.starts(with: "Optional<")
      || self.description.contains("!")
  }
}
