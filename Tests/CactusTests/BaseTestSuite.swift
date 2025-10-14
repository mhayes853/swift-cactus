import Cactus
import Testing

@Suite(nil, CleanupTrait())
struct BaseTestSuite {}

struct CleanupTrait: TestScoping, SuiteTrait {
  func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    try await function()
    if !CactusLanguageModel.isDownloadingTestModel {
      try? CactusLanguageModel.cleanupTestModel()
    }
  }
}
