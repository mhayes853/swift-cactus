// MARK: - CactusAgentModelKey

public struct CactusAgentModelKey: Hashable, Sendable {
  private let value: AnyHashableSendable

  public init(_ value: any Hashable & Sendable) {
    self.value = AnyHashableSendable(value)
  }
}

// MARK: - Conformances

extension CactusAgentModelKey: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self.init(value)
  }
}

extension CactusAgentModelKey: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.init(value)
  }
}

extension CactusAgentModelKey: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.init(value)
  }
}

extension CactusAgentModelKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}
