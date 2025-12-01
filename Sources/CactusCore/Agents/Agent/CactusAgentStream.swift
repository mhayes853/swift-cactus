// MARK: - CactusAgentStream

public struct CactusAgentStream<Output: ConvertibleFromCactusResponse> {
  public let continuation = Continuation()

  public init() {}

  public func collectResponse() async throws -> Output {
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
