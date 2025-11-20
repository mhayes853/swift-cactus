import Cactus
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `CactusLanguageModelMetadata tests` {
    @Test(.snapshots(record: .failed))
    func `Available Models`() async throws {
      let models = try await CactusLanguageModel.sharedAvailableModels()
      assertSnapshot(of: models, as: .json)
    }
  }
}
