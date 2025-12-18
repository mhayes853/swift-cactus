// MARK: - CactusAgentNamespace

public enum CactusAgentNamespace: Hashable, Sendable {
  case global
  case local(String)
}

// MARK: - Environment

extension CactusAgent {
  public func namespace(_ namespace: CactusAgentNamespace) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.namespace, namespace)
  }
}

extension CactusEnvironmentValues {
  public var namespace: CactusAgentNamespace {
    get { self[NamespaceAgentKey.self] }
    set { self[NamespaceAgentKey.self] = newValue }
  }

  private enum NamespaceAgentKey: Key {
    static let defaultValue = CactusAgentNamespace.global
  }
}
