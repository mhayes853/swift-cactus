import Cactus
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `CactusLanguageModelMetadata tests` {
    @Test(.disabled())
    func `Available Models`() async throws {
      let models = try await CactusLanguageModel.sharedAvailableModels()
      assertSnapshot(of: models, as: .json)
    }
  }
}
