/// A ``CactusAgentModelStore`` that can be shared across multiple ``CactusAgenticSession`` instances.
public final class SharedModelStore: CactusAgentModelStore, Sendable {
  private let state = Lock([AnyHashableSendable: Task<ModelCell, any Error>]())

  public init() {}

  public func prewarmModel(
    request: sending CactusAgentModelRequest
  ) async throws {
    _ = try await self.modelCell(for: request)
  }

  public func withModelAccess<T>(
    request: sending CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T {
    let cell = try await self.modelCell(for: request)
    return try cell.model.withLock { try operation($0) }
  }

  private func modelCell(
    for request: sending CactusAgentModelRequest
  ) async throws -> ModelCell {
    let key = AnyHashableSendable(request.key)
    if let cell = self.state.withLock({ $0[key] }) {
      return try await cell.value
    }
    let task = Task<ModelCell, any Error> {
      ModelCell(model: try await request.loader.loadModel(in: request.environment))
    }
    self.state.withLock { $0[key] = task }
    return try await task.value
  }

  private final class ModelCell: Sendable {
    let model: Lock<CactusLanguageModel>

    init(model: sending CactusLanguageModel) {
      self.model = Lock(model)
    }
  }
}
