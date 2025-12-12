import IssueReporting

@propertyWrapper
public struct Memory<Value: Sendable>: Sendable {
  private struct State {
    var environment: CactusEnvironmentValues?
    var flushTask: Task<Void, any Error>?
    var loadTask: Task<Value, any Error>?

    func value(for location: any CactusMemoryLocation<Value>) -> Value? {
      self.environment.flatMap { $0.memoryStore.value(at: location, in: $0) }
    }
  }

  private let box = LockedBox<State>(State())
  private let location: any CactusMemoryLocation<Value>
  private let _wrappedValue: @Sendable () -> Value

  public var wrappedValue: Value {
    get { self.box.inner.withLock { $0.value(for: self.location) ?? self._wrappedValue() } }
    nonmutating set {
      self.box.inner.withLock { state in
        guard let env = state.environment else { return }
        env.memoryStore.store(value: newValue, at: self.location, in: env)
        self.flush(state: &state, in: env, shouldReportIssue: true)
      }
    }
  }

  public var projectedValue: Self {
    self
  }

  public init(wrappedValue: @autoclosure @escaping @Sendable () -> Value, _ key: String) {
    self.init(wrappedValue: wrappedValue(), .inMemory(key))
  }

  public init(
    wrappedValue: @autoclosure @escaping @Sendable () -> Value,
    _ location: some CactusMemoryLocation<Value>
  ) {
    self.location = location
    self._wrappedValue = wrappedValue
  }

  @discardableResult
  public func hydrate(in environment: CactusEnvironmentValues) async throws -> Value {
    let task = self.box.inner.withLock { state in
      state.environment = environment
      if let value = state.value(for: self.location) {
        return Task<Value, any Error> { value }
      }
      return self._load(state: &state, in: environment, reason: .hydration)
    }
    return try await task.value
  }

  @discardableResult
  public func refresh(in environment: CactusEnvironmentValues) async throws -> Value {
    let task = self.box.inner.withLock { self._load(state: &$0, in: environment, reason: .refresh) }
    return try await task.value
  }

  private func _load(
    state: inout State,
    in environment: CactusEnvironmentValues,
    reason: CactusMemoryLoadReason
  ) -> Task<Value, any Error> {
    var env = environment
    env.memoryLoadReason = reason

    state.loadTask?.cancel()
    let value = state.value(for: self.location) ?? self._wrappedValue()
    let task = Task {
      do {
        let value = try await self.location.value(in: env, currentValue: value)
        environment.memoryStore.store(value: value, at: self.location, in: environment)
        return value
      } catch {
        guard reason == .hydration && !(error is CancellationError) else { throw error }
        reportIssue(error)
        throw error
      }
    }
    state.loadTask = task
    return task
  }

  public func flush(in environment: CactusEnvironmentValues) async throws {
    let task = self.box.inner.withLock { state -> Task<Void, any Error>? in
      guard let env = state.environment else { return nil }
      return self.flush(state: &state, in: env, shouldReportIssue: false)
    }
    try await task?.value
  }

  @discardableResult
  private func flush(
    state: inout State,
    in environment: CactusEnvironmentValues,
    shouldReportIssue: Bool
  ) -> Task<Void, any Error> {
    state.flushTask?.cancel()
    let value = state.value(for: self.location) ?? self._wrappedValue()
    let task = Task {
      do {
        return try await self.location.save(value: value, in: environment)
      } catch {
        guard shouldReportIssue && !(error is CancellationError) else { throw error }
        reportIssue(error)
        throw error
      }
    }
    state.flushTask = task
    return task
  }
}
