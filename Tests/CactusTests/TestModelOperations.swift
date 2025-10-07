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
      print("=== Downloading Model ===")
      let url = try await CactusLanguageModel.downloadModel(
        from: CactusLanguageModel.testModelMetadata().downloadURL,
        to: temporaryDirectory(),
        onProgress: { result in
          CactusLanguageModel.testModelDownloadProgress.withLock { $0.append(result) }
        }
      )
      print("=== Finished Downloading Model ===")
      registerCleanup()
      return url
    }
  }
}

private let testModelStore = OperationStore.detached(
  query: CactusLanguageModel.TestModelDownloadQuery().deduplicated(),
  initialValue: nil
)

private func registerCleanup() {
  atexit {
    guard let url = testModelStore.currentValue else { return }
    try? FileManager.default.removeItem(at: url)
  }
}

private struct TestModelNotFoundError: Error {}
