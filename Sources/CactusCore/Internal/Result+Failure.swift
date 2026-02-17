// MARK: - Result Failure Accessors

extension Result {
  package var failure: Failure? {
    switch self {
    case .success:
      nil
    case .failure(let error):
      error
    }
  }

  package var isFailure: Bool {
    self.failure != nil
  }
}
