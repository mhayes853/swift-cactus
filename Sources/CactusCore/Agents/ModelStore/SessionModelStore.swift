/// A ``CactusAgentModelStore`` that manages models for a single ``CactusAgenticSession``.
public final class SessionModelStore: CactusAgentModelStore {
  public init() {}

  public func prewarmModel(
    request: sending CactusAgentModelRequest<some CactusAgentModelLoader>
  ) async throws {

  }

  public func withModelAccess<T>(
    request: CactusAgentModelRequest<some CactusAgentModelLoader>,
    perform operation: (CactusLanguageModel) throws -> T
  ) async throws -> T {
    fatalError()
  }
}
