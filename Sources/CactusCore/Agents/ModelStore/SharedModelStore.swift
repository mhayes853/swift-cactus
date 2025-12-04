/// A ``CactusAgentModelStore`` that can be shared across multiple ``CactusAgenticSession`` instances.
public final class SharedModelStore: CactusAgentModelStore, Sendable {
  public static let `default` = SharedModelStore()

  public init() {}

  public func prewarmModel(
    request: sending CactusAgentModelRequest<some CactusAgentModelLoader>
  ) async throws {

  }

  public func withModelAccess<T>(
    request: sending CactusAgentModelRequest<some CactusAgentModelLoader>,
    perform operation: (CactusLanguageModel) throws -> T
  ) async throws -> T {
    fatalError()
  }
}
