struct NoopModelStore: CactusAgentModelStore {
  nonisolated(nonsending) func prewarmModel(request: sending CactusAgentModelRequest) async throws {
  }

  nonisolated(nonsending) func withModelAccess<T>(
    request: sending CactusAgentModelRequest,
    perform operation: (CactusLanguageModel) throws -> sending T
  ) async throws -> sending T {
    fatalError("This should never be called.")
  }
}
