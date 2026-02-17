import CXXCactusShims

// MARK: - CactusLanguageModelStopper

struct CactusLanguageModelStopper: @unchecked Sendable {
  private let model: CactusLanguageModel

  init(model: CactusLanguageModel) {
    self.model = model
  }

  func stop() {
    self.model.stop()
  }
}
