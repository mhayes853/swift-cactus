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
