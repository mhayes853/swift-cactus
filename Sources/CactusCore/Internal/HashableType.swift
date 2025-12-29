struct HashableType: Hashable, Sendable {
  let base: Any.Type

  init(_ base: Any.Type) {
    self.base = base
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    ObjectIdentifier(lhs.base) == ObjectIdentifier(rhs.base)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self.base))
  }
}
