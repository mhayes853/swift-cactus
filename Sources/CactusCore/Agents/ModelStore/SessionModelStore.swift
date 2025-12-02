/// A ``CactusAgentModelStore`` that manages models for a single ``CactusAgenticSession``.
public final class SessionModelStore: CactusAgentModelStore {
  public init() {}

  public func withModelAccess<T>(
    for request: any CactusAgentModelRequest,
    environment: CactusEnvironmentValues,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T {
    fatalError()
  }
}
