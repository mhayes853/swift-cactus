import CXXCactusShims

// MARK: - CactusLanguageModelStopper

// NB: @unchecked Sendable is fine because model.stop is thread-safe.
struct CactusLanguageModelStopper: @unchecked Sendable {
  private let model: CactusLanguageModel

  init(model: CactusLanguageModel) {
    self.model = model
  }

  func stop() {
    self.model.stop()
  }
}
