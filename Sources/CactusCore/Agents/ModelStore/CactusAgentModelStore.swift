// MARK: - CactusAgentModelRequest

public struct CactusAgentModelRequest<Loader: CactusAgentModelLoader> {
  public let key: AnyHashable
  public let loader: Loader
  public let environment: CactusEnvironmentValues

  public init(
    key: AnyHashable,
    loader: Loader,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.key = key
    self.loader = loader
    self.environment = environment
  }
}

// MARK: - CactusModelStore

/// A protocol for accessing and managing `CactusLanguageModel` instances used by agents.
public protocol CactusAgentModelStore {
  func prewarmModel<Loader>(request: CactusAgentModelRequest<Loader>) async throws

  func withModelAccess<T, Loader>(
    request: CactusAgentModelRequest<Loader>,
    perform operation: (CactusLanguageModel) throws -> T
  ) async throws -> T
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
