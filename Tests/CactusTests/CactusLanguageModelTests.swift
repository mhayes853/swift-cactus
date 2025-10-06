import Cactus
import SnapshotTesting
import Testing

@Suite("CactusLanguageModel tests")
struct CactusLanguageModelTests {
  @Test("Available Models")
  func availableModels() async throws {
    let models = try await CactusLanguageModel.sharedAvailableModels()
    assertSnapshot(of: models, as: .json)
  }
}
