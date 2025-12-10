// MARK: - CactusAgentModelKey

public struct CactusAgentModelKey: Hashable, Sendable {
  private let value: AnyHashableSendable

  public init(_ value: any Hashable & Sendable) {
    self.value = AnyHashableSendable(value)
  }
}

// MARK: - Conformances

extension CactusAgentModelKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}
