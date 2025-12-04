import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `DirectoryModelLoader tests` {
  @Test
  func `Begins Downloading Model When Not Stored On Disk`() async throws {
    let request: some CactusAgentModelLoader = .fromDirectory(slug: "blob", directory: .testModels)
    let error = await #expect(throws: DirectoryModelLoaderError.self) {
      _ = try await request.loadModel(in: CactusEnvironmentValues())
    }
    expectNoDifference(error, .modelDownloading)

    try CactusModelsDirectory.testModels.modelDownloadTask(for: "blob").cancel()
  }

  @Test
  func `Model Not Found When Is Not Persisted And No Downloading Behavior`() async throws {
    let request: some CactusAgentModelLoader = .fromDirectory(
      slug: "blob",
      directory: .testModels,
      downloadBehavior: .noDownloading
    )
    await #expect(throws: DirectoryModelLoaderError.modelNotFound) {
      _ = try await request.loadModel(in: CactusEnvironmentValues())
    }
  }

  @Test
  func `Loads Model When Found In Directory`() async throws {
    _ = try await CactusLanguageModel.testModelURL()
    let request: some CactusAgentModelLoader = .fromDirectory(
      slug: CactusLanguageModel.testModelSlug,
      directory: .testModels
    )
    let model = try await request.loadModel(in: CactusEnvironmentValues())
    expectNoDifference(model.configuration.modelSlug, CactusLanguageModel.testModelSlug)
  }

  @Test
  func `Throws Model Downloading Error When Download Started Externally`() async throws {
    let downloadTask = try CactusModelsDirectory.testModels.modelDownloadTask(for: "blob")

    let request: some CactusAgentModelLoader = .fromDirectory(slug: "blob", directory: .testModels)
    await #expect(throws: DirectoryModelLoaderError.modelDownloading) {
      _ = try await request.loadModel(in: CactusEnvironmentValues())
    }

    downloadTask.cancel()
  }

  @Test
  func `Waits For Model Download When Download Behavior Specifies Waiting`() async throws {
    let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
    let request: some CactusAgentModelLoader = .fromDirectory(
      audioSlug: "whisper-tiny",
      directory: directory,
      downloadBehavior: .waitForDownload(.default)
    )
    let model = try await request.loadModel(in: CactusEnvironmentValues())
    expectNoDifference(model.configuration.modelSlug, "whisper-tiny")

    try FileManager.default.removeItem(at: directory.baseURL)
  }
}
