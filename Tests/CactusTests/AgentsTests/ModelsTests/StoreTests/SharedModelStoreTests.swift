import Cactus
import CustomDump
import Testing

@Suite
struct `SharedModelStore tests` {
  @Test
  func `Access Model When Requested`() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    let store = SharedModelStore()
    await #expect(throws: Never.self) {
      try await store.withModelAccess(
        request: CactusAgentModelRequest(loader: .url(url))
      ) { _ in }
    }
  }

  @Test
  func `Uses Same Model Instance For Request With Same Key`() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    let store = SharedModelStore()

    var id1: ObjectIdentifier?
    var id2: ObjectIdentifier?

    try await store.withModelAccess(request: CactusAgentModelRequest(loader: .url(url))) {
      id1 = ObjectIdentifier($0)
    }
    try await store.withModelAccess(request: CactusAgentModelRequest(loader: .url(url))) {
      id2 = ObjectIdentifier($0)
    }
    expectNoDifference(id1, id2)
  }

  @Test
  func `Only Loads Model Once For Same Key`() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    let loader = CountingModelLoader(key: "blob", url: url)
    let store = SharedModelStore()
    try await store.prewarmModel(request: CactusAgentModelRequest(loader: loader))
    try await store.prewarmModel(request: CactusAgentModelRequest(loader: loader))
    loader.count.withLock { expectNoDifference($0, 1) }
  }

  @Test
  func `Loads Model Twice For Different Keys`() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    let loader = CountingModelLoader(key: "blob", url: url)
    let store = SharedModelStore()
    try await store.prewarmModel(request: CactusAgentModelRequest(loader: loader))

    loader.key.withLock { $0 = "blob2" }
    try await store.prewarmModel(request: CactusAgentModelRequest(loader: loader))
    loader.count.withLock { expectNoDifference($0, 2) }
  }

  @Test
  func `Deduplicates Concurrent Request For The Same Model`() async throws {
    let url = try await CactusLanguageModel.testModelURL()
    let loader = CountingModelLoader(key: "blob", url: url)
    let store = SharedModelStore()
    async let r1: Void = store.prewarmModel(request: CactusAgentModelRequest(loader: loader))
    async let r2: Void = store.prewarmModel(request: CactusAgentModelRequest(loader: loader))
    _ = try await (r1, r2)
    loader.count.withLock { expectNoDifference($0, 1) }
  }
}
