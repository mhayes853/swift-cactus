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

  @Test("Generates Embeddings")
  @available(iOS 26.0, watchOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
  func generatesEmbeddings() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.embeddings(for: "This is some text.")
    assertSnapshot(of: embeddings, as: .dump)
  }

  @Test("Throws Buffer Too Small Error When Buffer Size Too Small")
  func throwsBufferTooSmallErrorWhenBufferSizeTooSmall() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", bufferSize: 20)
    }
  }

  @Test("Throws Buffer Too Small Error When Buffer Size Zero")
  func throwsBufferTooSmallErrorWhenBufferSizeZero() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", bufferSize: 0)
    }
  }

  @Test("Available Models")
  func availableModels() async throws {
    let models = try await CactusLanguageModel.sharedAvailableModels()
    assertSnapshot(of: models, as: .json)
  }
}
