// MARK: - CactusAgentStream

public struct CactusAgentStream<Output> {
}

// MARK: - Collect

extension CactusAgentStream where Output: ConvertibleFromJSONValue {
  public func collect() async throws -> Output {
    fatalError()
  }
}

extension CactusAgentStream where Output == String {
  public func collect() async throws -> String {
    fatalError()
  }
}

// MARK: - AsyncSequence

extension CactusAgentStream: AsyncSequence where Output: JSONValue.Generable {
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
