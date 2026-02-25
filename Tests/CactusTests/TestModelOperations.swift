import Cactus
import Foundation
import Operation

let nanosecondsPerSecond = UInt64(1_000_000_000)

// MARK: - TestModelDownloadQuery

extension CactusLanguageModel {
  static func testModelURL(
    request: CactusLanguageModel.PlatformDownloadRequest
  ) async throws -> URL {
    try await client.store(for: TestModelDownloadOperations.$downloadQuery(for: request)).fetch()
  }
}

private enum TestModelDownloadOperations {
  @QueryRequest
  static func downloadQuery(
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
}

extension CactusModelsDirectory {
  static let testModels = CactusModelsDirectory(baseURL: .swiftCactusTestsDirectory)
}

extension URL {
  static let swiftCactusTestsDirectory = {
    #if os(macOS)
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".swift-cactus-tests")
    #else
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(".swift-cactus-tests")
    #endif
  }()
}

private let client = OperationClient()
