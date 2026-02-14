struct NonThinkingTokenAccumulator {
  private var isInsideThinkTag = false
  private(set) var response = ""

  @discardableResult
  mutating func append(_ token: String) -> String? {
    switch token {
    case "<think>":
      self.isInsideThinkTag = true
      return nil
    case "</think>":
      self.isInsideThinkTag = false
      return nil
    default:
      guard !self.isInsideThinkTag else { return nil }
      self.response += token
      return token
    }
  }
}
