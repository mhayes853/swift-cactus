import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `DirectoryModelLoader tests` {
  @Test
  func `Begins Downloading Model When Not Stored On Disk`() async throws {
    let request = CactusLanguageModel.PlatformDownloadRequest(slug: "blob")
    let loader: some CactusLanguageModelLoader = .slug(request.slug, directory: .testModels)
    let error = await #expect(throws: DirectoryModelLoaderError.self) {
      _ = try await loader.loadModel(in: CactusEnvironmentValues())
    }
    expectNoDifference(error, .modelDownloading)

    let task = try CactusModelsDirectory.testModels.modelDownloadTask(for: request)
    expectNoDifference(task.isPaused, false)
    task.cancel()
  }

  @Test
  func `Model Not Found When Is Not Persisted And No Downloading Behavior`() async throws {
    let request = CactusLanguageModel.PlatformDownloadRequest(slug: "blob")
    let loader: some CactusLanguageModelLoader = .slug(
      request.slug,
      directory: .testModels,
      downloadBehavior: .noDownloading
    )
    await #expect(throws: DirectoryModelLoaderError.modelNotFound) {
      _ = try await loader.loadModel(in: CactusEnvironmentValues())
    }
  }

  @Test
  func `Loads Model When Found In Directory`() async throws {
    let request = CactusLanguageModel.testModelRequest
    _ = try await CactusLanguageModel.testModelURL(request: request)
    let loader: some CactusLanguageModelLoader = .slug(
      request.slug,
      directory: .testModels
    )
    let model = try await loader.loadModel(in: CactusEnvironmentValues())
    expectNoDifference(model.configuration.modelSlug, request.slug)
  }

  @Test
  func `Throws Model Downloading Error When Download Started Externally`() async throws {
    let request = CactusLanguageModel.PlatformDownloadRequest(slug: "blob")
    let downloadTask = try CactusModelsDirectory.testModels.modelDownloadTask(for: request)

    let loader: some CactusLanguageModelLoader = .slug(request.slug, directory: .testModels)
    await #expect(throws: DirectoryModelLoaderError.modelDownloading) {
      _ = try await loader.loadModel(in: CactusEnvironmentValues())
    }

    downloadTask.cancel()
  }

  @Test
  func `Waits For Model Download When Download Behavior Specifies Waiting`() async throws {
    let directory = CactusModelsDirectory(baseURL: temporaryModelDirectory())
    let request = CactusLanguageModel.PlatformDownloadRequest(slug: "whisper-tiny")
    let loader: some CactusAudioModelLoader = .slug(
      request.slug,
      directory: directory,
      downloadBehavior: .waitForDownload(.default)
    )
    let model = try await loader.loadModel(in: CactusEnvironmentValues())
    expectNoDifference(model.configuration.modelSlug, request.slug)

    try FileManager.default.removeItem(at: directory.baseURL)
  }
}
