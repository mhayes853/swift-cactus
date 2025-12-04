import Cactus
import Foundation

final class CountingModelLoader: CactusAgentModelLoader, Sendable {
  let count = Lock(0)
  private let url: URL

  init(url: URL) {
    self.url = url
  }

  func loadModel(in environment: CactusEnvironmentValues) async throws -> CactusLanguageModel {
    self.count.withLock { $0 += 1 }
    return try CactusLanguageModel(from: self.url)
  }
}
