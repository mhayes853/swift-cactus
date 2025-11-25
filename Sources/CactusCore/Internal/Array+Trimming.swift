extension Array {
  mutating func trimming(while predicate: (Element) -> Bool) {
    var lastN = 0
    for element in self.reversed() {
      if !predicate(element) {
        break
      }
      lastN += 1
    }

    var firstN = 0
    for element in self {
      if !predicate(element) {
        break
      }
      firstN += 1
    }

    self.removeFirst(firstN)
    self.removeLast(lastN)
  }
}
