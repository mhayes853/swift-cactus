/// A ``CactusAgentModelStore`` that manages models for a single ``CactusAgenticSession``.
public final class SessionModelStore: CactusAgentModelStore {
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
