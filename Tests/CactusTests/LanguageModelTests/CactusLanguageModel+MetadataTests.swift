import Cactus
import SnapshotTesting
import Testing

@Suite(.snapshots(record: .failed))
struct `CactusLanguageModelMetadata tests` {
  @Test
  func `Available Models`() async throws {
    let models = try await CactusLanguageModel.availableModels()
    assertSnapshot(of: models, as: .json)
  }

  @Test
  func `Available Audio Models`() async throws {
    let models = try await CactusLanguageModel.availableAudioModels()
    assertSnapshot(of: models, as: .json)
  }
}
