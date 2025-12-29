extension Sequence where Element: Hashable {
  var isUnique: Bool {
    var items = Set<Element>()
    for item in self {
      if !items.insert(item).inserted {
        return false
      }
    }
    return true
  }
}
