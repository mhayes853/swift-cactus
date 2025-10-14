import Cactus
import Foundation
import Operation

// MARK: - AvailableModelsQuery

extension CactusLanguageModel {
  private static let availableModelsStore = OperationStore.detached(
    query: AvailableModelsQuery().deduplicated(),
    initialValue: nil
  )

  static func sharedAvailableModels() async throws -> [Metadata] {
    let store = Self.availableModelsStore
    if let currentMetadata = store.currentValue {
      return currentMetadata
    }
    return try await store.fetch()
  }

  struct AvailableModelsQuery: QueryRequest, Hashable {
    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<[Metadata], any Error>
    ) async throws -> [Metadata] {
      try await CactusLanguageModel.availableModels()
    }
  }
}

// MARK: - TestModelDownloadQuery

extension CactusLanguageModel {
  private static let testModelStore = OperationStore.detached(
    query: TestModelDownloadQuery().deduplicated(),
    initialValue: nil
  )

  static func testModelURL() async throws -> URL {
    if let url = testModelStore.currentValue {
      return url
    }
    return try await testModelStore.fetch()
  }

  static func testModelMetadata() async throws -> Metadata {
    let metadata = try await Self.sharedAvailableModels()
    let testModelMetadata = metadata.first { $0.slug == Self.testModelSlug }
    guard let testModelMetadata else { throw TestModelNotFoundError() }
    return testModelMetadata
  }

  static let testModelDownloadProgress = Lock([Result<DownloadProgress, any Error>]())
  static let testModelSlug = "qwen3-0.6"

  struct TestModelDownloadQuery: QueryRequest, Hashable {
    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<URL, any Error>
    ) async throws -> URL {
      print("=== Downloading Test Model ===")
      let url = try await CactusLanguageModel.downloadModel(
        slug: CactusLanguageModel.testModelSlug,
        to: temporaryModelDirectory().appendingPathComponent(CactusLanguageModel.testModelSlug),
        onProgress: { result in
          CactusLanguageModel.testModelDownloadProgress.withLock { $0.append(result) }
        }
      )
      print("=== Finished Downloading Test Model ===")
      return url
    }
  }
}

extension CactusLanguageModel {
  static var isDownloadingTestModel: Bool {
    testModelStore.isLoading
  }

  static func cleanupTestModel() throws {
    try testModelStore.withExclusiveAccess { store in
      guard let url = store.currentValue else { return }
      print("=== Cleaning Up Test Model ===")
      try FileManager.default.removeItem(at: url)
      store.resetState()
    }
  }
}

private let testModelStore = OperationStore.detached(
  query: CactusLanguageModel.TestModelDownloadQuery().deduplicated(),
  initialValue: nil
)

private struct TestModelNotFoundError: Error {}
