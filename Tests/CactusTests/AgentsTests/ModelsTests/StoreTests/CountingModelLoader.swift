import Cactus
import Foundation

final class CountingModelLoader: CactusLanguageModelLoader, Sendable {
  let count = Lock(0)
  private let url: URL
  let key: Lock<CactusAgentModelKey>

  init(key: CactusAgentModelKey, url: URL) {
    self.key = Lock(key)
    self.url = url
  }

  func key(in environment: CactusEnvironmentValues) -> CactusAgentModelKey {
    self.key.withLock { $0 }
  }

  func slug(in environment: CactusEnvironmentValues) -> String {
    "counting"
  }

  func loadModel(
    in environment: CactusEnvironmentValues
  ) async throws -> sending CactusLanguageModel {
    try await Task.sleep(nanoseconds: twoHundredMillis)  // NB: Give a chance for deduplication to occur.
    self.count.withLock { $0 += 1 }
    return try CactusLanguageModel(from: self.url)
  }
}

private let twoHundredMillis = UInt64(200_000_000)
