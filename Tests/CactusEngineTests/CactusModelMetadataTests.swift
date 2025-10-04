import CactusEngine
import SnapshotTesting
import Testing

@Suite("CactusModelMetadata tests")
struct CactusModelMetadataTests {
  @Test("Available Models")
  func availableModels() async throws {
    let models = try await CactusModelMetadata.availableModels()
    assertSnapshot(of: models, as: .json)
  }
}
