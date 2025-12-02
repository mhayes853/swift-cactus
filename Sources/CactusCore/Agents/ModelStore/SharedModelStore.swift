/// A ``CactusAgentModelStore`` that can be shared across multiple ``CactusAgenticSession`` instances.
public final class SharedModelStore: CactusAgentModelStore, Sendable {
  public static let `default` = SharedModelStore()

  public init() {}

  public func withModelAccess<T>(
    for request: any CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T {
    fatalError()
  }
}
