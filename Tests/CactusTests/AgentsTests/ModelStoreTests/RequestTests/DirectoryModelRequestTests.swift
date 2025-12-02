import Cactus
import CustomDump
import Testing

@Suite
struct `DirectoryModelRequest tests` {
  @Test
  func `Begins Downloading Model When Not Stored On Disk`() throws {
    let request: some CactusAgentModelRequest = .fromDirectory(slug: "blob", directory: .testModels)
    let error = #expect(throws: DirectoryModelRequestError.self) {
      try request.loadModel()
    }
    expectNoDifference(error, .modelDownloading)

    try CactusModelsDirectory.testModels.modelDownloadTask(for: "blob").cancel()
  }

  @Test
  func `Model Not Found When Is Not Persisted And No Download Configuration`() throws {
    let request: some CactusAgentModelRequest = .fromDirectory(
      slug: "blob",
      directory: .testModels,
      downloadConfiguration: nil
    )
    let error = #expect(throws: DirectoryModelRequestError.self) {
      try request.loadModel()
    }
    expectNoDifference(error, .modelNotFound)
  }

  @Test
  func `Loads Model When Found In Directory`() async throws {
    _ = try await CactusLanguageModel.testModelURL()
    let request: some CactusAgentModelRequest = .fromDirectory(
      slug: CactusLanguageModel.testModelSlug,
      directory: .testModels,
      downloadConfiguration: nil
    )
    let model = try request.loadModel()
    expectNoDifference(model.configuration.modelSlug, CactusLanguageModel.testModelSlug)
  }

  @Test
  func `Throws Model Downloading Error When Download Started Externally`() throws {
    let downloadTask = try CactusModelsDirectory.testModels.modelDownloadTask(for: "blob")

    let request: some CactusAgentModelRequest = .fromDirectory(slug: "blob", directory: .testModels)
    let error = #expect(throws: DirectoryModelRequestError.self) {
      try request.loadModel()
    }
    expectNoDifference(error, .modelDownloading)

    downloadTask.cancel()
  }
}
