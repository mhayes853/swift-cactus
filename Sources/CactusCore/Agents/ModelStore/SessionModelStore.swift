/// A ``CactusAgentModelStore`` that manages models for a single ``CactusAgenticSession``.
public final class SessionModelStore: CactusAgentModelStore {
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
