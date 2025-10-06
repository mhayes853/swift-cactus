import CactusEngine
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
    if let url = Self.testModelStore.currentValue {
      return url
    }
    return try await Self.testModelStore.fetch()
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
      try await CactusLanguageModel.downloadModel(
        with: CactusLanguageModel.testModelMetadata(),
        to: temporaryDirectory(),
        onProgress: { result in
          CactusLanguageModel.testModelDownloadProgress.withLock { $0.append(result) }
        }
      )
    }
  }
}

private struct TestModelNotFoundError: Error {}

private func temporaryDirectory() async throws -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent("tmp-model-\(UUID())")
}
