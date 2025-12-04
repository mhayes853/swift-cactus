/// A ``CactusAgentModelStore`` that can be shared across multiple ``CactusAgenticSession`` instances.
public final class SharedModelStore: CactusAgentModelStore, Sendable {
  public static let `default` = SharedModelStore()

  public init() {}

  public func prewarmModel<Loader>(request: CactusAgentModelRequest<Loader>) async throws {

  }

  public func withModelAccess<T, Loader>(
    request: CactusAgentModelRequest<Loader>,
    perform operation: (CactusLanguageModel) throws -> T
  ) async throws -> T {
    fatalError()
  }
}
