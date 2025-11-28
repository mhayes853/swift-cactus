import Cactus
import Foundation
import Operation

// MARK: - TestModelDownloadQuery

extension CactusLanguageModel {
  static func testModelURL(slug: String = testModelSlug) async throws -> URL {
    try await client.store(for: $downloadQuery(for: slug)).fetch()
  }

  static let testFunctionCallingModelSlug = "qwen3-0.6"
  static let testModelSlug = "lfm2-1.2b"
  static let testVLMSlug = "lfm2-vl-450m"
  static let testTranscribeSlug = "whisper-small"

  @QueryRequest
  private static func downloadQuery(for slug: String) async throws -> URL {
    if let url = CactusModelsDirectory.testModels.storedModelURL(for: slug) {
      return url
    }
    print("=== Downloading Test Model (\(slug)) ===")
    let url = try await CactusModelsDirectory.testModels.modelURL(for: slug)
    print("=== Finished Downloading Test Model (\(slug)) ===")
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
