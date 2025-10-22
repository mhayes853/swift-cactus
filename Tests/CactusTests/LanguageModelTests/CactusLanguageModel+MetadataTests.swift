import Cactus
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `CactusLanguageModelMetadata tests` {
    @Test
    func `Available Models`() async throws {
      let models = try await CactusLanguageModel.sharedAvailableModels()
      assertSnapshot(of: models, as: .json)
    }
  }
}
