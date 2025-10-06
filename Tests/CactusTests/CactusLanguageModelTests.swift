import Cactus
import CustomDump
import SnapshotTesting
import Testing

@Suite("CactusLanguageModel tests")
struct CactusLanguageModelTests {
  @Test("Attempt To Create Model From Non-Existent URL, Throws Error")
  func attemptToCreateModelFromNonExistentURLThrowsError() async throws {
    let error = #expect(throws: CactusLanguageModel.ModelCreationError.self) {
      try CactusLanguageModel(from: temporaryDirectory())
    }
    expectNoDifference(error?.message.starts(with: "Failed to create model from:"), true)
  }

  @Test("Successfully Creates Model From Downloaded Model")
  func successfullyCreatesModelFromDownloadedModel() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    #expect(throws: Never.self) {
      try CactusLanguageModel(from: modelURL)
    }
  }

  @Test("Available Models")
  func availableModels() async throws {
    let models = try await CactusLanguageModel.sharedAvailableModels()
    assertSnapshot(of: models, as: .json)
  }
}
