import CXXCactusShims

// MARK: - CactusModelStopper

// NB: @unchecked Sendable is fine because cactus_stop is thread-safe.
struct CactusModelStopper: @unchecked Sendable {
  private let modelPointer: cactus_model_t

  init(modelPointer: cactus_model_t) {
    self.modelPointer = modelPointer
  }

  func stop() {
    cactus_stop(self.modelPointer)
  }
}
