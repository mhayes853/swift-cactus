import Foundation

// MARK: - CactusAgentModelRequest

public struct CactusAgentModelRequest {
  public let loader: any CactusAgentModelLoader
  public let environment: CactusEnvironmentValues

  public init(
    _ loader: any CactusAgentModelLoader,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.loader = loader
    self.environment = environment
  }
}

// MARK: - CactusModelStore

/// A protocol for accessing and managing `CactusLanguageModel` instances used by agents.
public protocol CactusAgentModelStore: Sendable {
  func prewarmModel(request: sending CactusAgentModelRequest) async throws

  func withModelAccess<T>(
    request: sending CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T
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
