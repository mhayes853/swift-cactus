/// A ``CactusAgentModelStore`` that can be shared across multiple ``CactusAgenticSession`` instances.
public final class SharedModelStore: CactusAgentModelStore, Sendable {
  public static let `default` = SharedModelStore()

  public init() {}

  public func withModelAccess<T>(
    slug: String,
    in directory: CactusModelsDirectory,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T {
    fatalError()
  }

  public func withModelAccess<T>(
    configuration: CactusLanguageModel.Configuration,
    perform operation: (CactusLanguageModel) throws -> T
  ) throws -> T {
    fatalError()
  }
}
