extension Int64 {
  func clamped(in range: Range<Self>) -> Self? {
    guard !range.isEmpty else { return nil }
    if self < range.lowerBound {
      return range.lowerBound
    } else if self >= range.upperBound {
      return range.upperBound.advanced(by: -1)
    } else {
      return self
    }
  }
}
