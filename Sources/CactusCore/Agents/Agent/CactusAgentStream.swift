// MARK: - CactusAgentStream

public struct CactusAgentStream<Output> {
}

// MARK: - AsyncSequence

extension CactusAgentStream: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    public typealias Element = Output

    public mutating func next() async throws -> Output? {
      fatalError()
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator()
  }
}

// MARK: - Continuation

extension CactusAgentStream {
  public struct Continuation {

  }
}
