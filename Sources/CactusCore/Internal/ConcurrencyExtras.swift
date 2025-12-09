// MARK: - Task Mega Yield

extension Task where Success == Never, Failure == Never {
  package static func megaYield(count: Int = 20) async {
    for _ in 0..<count {
      await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
  }
}

// MARK: - Task Never

extension Task where Failure == Never {
  package static func never() async throws -> Success {
    let stream = AsyncStream<Success> { _ in }
    for await element in stream {
      return element
    }
    throw _Concurrency.CancellationError()
  }
}

extension Task where Success == Never, Failure == Never {
  package static func never() async throws {
    let stream = AsyncStream<Success> { _ in }
    for await _ in stream {}
    throw _Concurrency.CancellationError()
  }
}

// MARK: - Task Cancellable Value

extension Task where Failure == Never {
  package var cancellableValue: Success {
    get async {
      await withTaskCancellationHandler {
        await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}

extension Task where Failure == Error {
  package var cancellableValue: Success {
    get async throws {
      try await withTaskCancellationHandler {
        try await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}

// MARK: - Result

extension Result {
  @_transparent
  package init(catching body: () async throws(Failure) -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}

// MARK: - Isolate

package func isolate<T, E: Error, A: Actor>(
  _ a: A,
  _ fn: (isolated A) async throws(E) -> sending T
) async throws(E) -> sending T {
  try await fn(a)
}
