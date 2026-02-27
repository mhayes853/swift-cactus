import Foundation

extension Duration {
  var secondsDouble: Double {
    let (seconds, attoseconds) = components
    return Double(seconds) + Double(attoseconds) / Double(1_000_000_000_000_000_000)
  }
}
