/// A ``CactusAgentModelStore`` that manages models for a single ``CactusAgenticSession``.
public final class SessionModelStore: CactusAgentModelStore {
  private var models = [AnyHashable: CactusLanguageModel]()

  public init() {}

  public func prewarmModel(
    request: sending CactusAgentModelRequest
  ) async throws {
    _ = try await self.model(for: request)
  }

  public func withModelAccess<T>(
    request: sending CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T {
    let model = try await self.model(for: request)
    return try operation(model)
  }

  private nonisolated(nonsending) func model(
    for request: sending CactusAgentModelRequest
  ) async throws -> CactusLanguageModel {
    if let model = self.models[AnyHashable(request.key)] {
      return model
    }
    let model = try await request.loader.loadModel(in: request.environment)
    self.models[AnyHashable(request.key)] = model
    return model
  }
}
