struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed == 0 ? 0xdeca_fbad : seed
  }

  mutating func next() -> UInt64 {
    self.state = 6_364_136_223_846_793_005 &* self.state &+ 1
    return self.state
  }
}
