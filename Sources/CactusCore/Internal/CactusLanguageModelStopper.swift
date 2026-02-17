import CXXCactusShims

// MARK: - CactusLanguageModelStopper

struct CactusLanguageModelStopper: @unchecked Sendable {
  private let model: cactus_model_t

  init(model: cactus_model_t) {
    self.model = model
  }

  func stop() {
    cactus_stop(self.model)
  }
}
