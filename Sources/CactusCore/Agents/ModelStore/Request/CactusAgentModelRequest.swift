public protocol CactusAgentModelRequest {
  associatedtype ID: Hashable

  func id(in environment: CactusEnvironmentValues) -> ID

  func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel
}

extension CactusAgentModelRequest where Self: Identifiable {
  public func id(in environment: CactusEnvironmentValues) -> ID {
    self.id
  }
}
