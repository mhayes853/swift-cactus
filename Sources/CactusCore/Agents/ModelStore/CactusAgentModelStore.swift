// MARK: - CactusModelStore

/// A protocol for accessing and managing `CactusLanguageModel` instances used by agents.
public protocol CactusAgentModelStore {
  func withModelAccess<T>(
    for request: any CactusAgentModelRequest,
    environment: CactusEnvironmentValues,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T
}

// MARK: - Environment

extension CactusAgent {
  public func modelStore(_ store: any CactusAgentModelStore) -> _TransformEnvironmentAgent<Self> {
    self.environment(\.modelStore, store)
  }
}

extension CactusEnvironmentValues {
  public var modelStore: any CactusAgentModelStore {
    get { self[ModelStoreKey.self] }
    set { self[ModelStoreKey.self] = newValue }
  }

  private enum ModelStoreKey: Key {
    static var defaultValue: any CactusAgentModelStore {
      SharedModelStore.default
    }
  }
}
