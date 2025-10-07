import Cactus
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite("CactusLanguageModelMetadata tests")
  struct CactusLanguageModelMetadata {
    @Test("Available Models")
    func availableModels() async throws {
      let models = try await CactusLanguageModel.sharedAvailableModels()
      assertSnapshot(of: models, as: .json)
    }
  }
}
