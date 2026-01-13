import Cactus
import Foundation
import Operation

// MARK: - TestModelDownloadQuery

extension CactusLanguageModel {
  static func testModelURL(
    request: CactusLanguageModel.PlatformDownloadRequest = testModelRequest
  ) async throws -> URL {
    try await client.store(for: $downloadQuery(for: request)).fetch()
  }

  static func testAudioModelURL(
    request: CactusLanguageModel.PlatformDownloadRequest = testTranscribeRequest
  ) async throws -> URL {
    try await client.store(for: $audioDownloadQuery(for: request)).fetch()
  }

  static let testFunctionCallingModelRequest = CactusLanguageModel.PlatformDownloadRequest
    .qwen3_0_6b()
  static let testModelRequest = CactusLanguageModel.PlatformDownloadRequest.qwen3_0_6b()
  static let testVLMRequest = CactusLanguageModel.PlatformDownloadRequest.lfm2Vl_450m()
  static let testTranscribeRequest = CactusLanguageModel.PlatformDownloadRequest.whisperSmall()

  @QueryRequest
  private static func downloadQuery(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) async throws -> URL {
    if let url = CactusModelsDirectory.testModels.storedModelURL(for: request) {
      return url
    }
    print("=== Downloading Test Model (\(request.slug)) ===")
    let url = try await CactusModelsDirectory.testModels.modelURL(for: request)
    print("=== Finished Downloading Test Model (\(request.slug)) ===")
    return url
  }

  @QueryRequest
  private static func audioDownloadQuery(
    for request: CactusLanguageModel.PlatformDownloadRequest
  ) async throws -> URL {
    if let url = CactusModelsDirectory.testModels.storedModelURL(for: request) {
      return url
    }
    print("=== Downloading Test Audio Model (\(request.slug)) ===")
    let url = try await CactusModelsDirectory.testModels.modelURL(for: request)
    print("=== Finished Downloading Test Audio Model (\(request.slug)) ===")
    return url
  }
}

extension CactusModelsDirectory {
  static let testModels = CactusModelsDirectory(baseURL: .swiftCactusTestsDirectory)
}

extension URL {
  static let swiftCactusTestsDirectory = {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(".swift-cactus-tests")
  }()
}

private let client = OperationClient()
