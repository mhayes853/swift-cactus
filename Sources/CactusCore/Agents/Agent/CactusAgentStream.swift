// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: ConvertibleFromCactusResponse> {
}

// MARK: - Collect

extension CactusAgentStream {
  public func collect() async throws -> Output {
    fatalError()
  }
}

// MARK: - AsyncSequence

extension CactusAgentStream: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    public mutating func next() async throws -> Output.Partial? {
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
