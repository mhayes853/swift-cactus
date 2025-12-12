import Foundation

// MARK: - CactusAgentRequest

public struct CactusAgentRequest<Input> {
  public var input: Input
  public var environment: CactusEnvironmentValues

  public init(
    input: Input,
    environment: CactusEnvironmentValues = CactusEnvironmentValues()
  ) {
    self.input = input
    self.environment = environment
  }
}

extension CactusAgentRequest: Sendable where Input: Sendable {}

// MARK: - CactusAgentResponse

public struct CactusAgentResponse<Output: Sendable>: Sendable {
  public var output: Output
  public var metrics: CactusMessageMetrics

  public init(output: Output, metrics: CactusMessageMetrics) {
    self.output = output
    self.metrics = metrics
  }
}

// MARK: - CactusAgent

public protocol CactusAgent<Input, Output> {
  associatedtype Input
  associatedtype Output: Sendable

  associatedtype Body

  @CactusAgentBuilder<Input, Output>
  func body(environment: CactusEnvironmentValues) -> Body

  nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response
}

extension CactusAgent where Body == Never {
  @_transparent
  public func body(environment: CactusEnvironmentValues) -> Never {
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not invoke an agent's 'body' method directly, as it may not exist. To run an agent, \
      call 'CactusAgent.stream(request:into:)', instead.
      """
    )
  }
}

extension CactusAgent where Body: CactusAgent<Input, Output> {
  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws -> CactusAgentStream<Output>.Response {
    self.hydrateMemory(in: request.environment)
    defer { self.collectMemory(in: request.environment) }

    let agent = self.body(environment: request.environment)

    var request = request
    request.environment.hydrationKey.level += 1
    return try await agent.stream(request: request, into: continuation)
  }
}

// MARK: - Hydration

extension CactusAgent {
  private func hydrateMemory(in environment: CactusEnvironmentValues) {
    var key = environment.hydrationKey
    for child in Mirror(reflecting: self).children {
      guard let child = child.value as? any Hydratable else { continue }
      if let value = environment.memoryStore[key] {
        child.hydrate(with: value)
      }
      key.index += 1
    }
  }

  private func collectMemory(in environment: CactusEnvironmentValues) {
    var key = environment.hydrationKey
    for child in Mirror(reflecting: self).children {
      guard let child = child.value as? any Hydratable else { continue }
      environment.memoryStore[key] = child.collectableValue
      key.index += 1
    }
  }
}

private protocol Hydratable {
  var collectableValue: any Sendable { get }
  func hydrate(with value: any Sendable)
}

extension Memory: Hydratable {
  var collectableValue: any Sendable {
    self.wrappedValue
  }

  func hydrate(with value: any Sendable) {
    guard let value = value as? Value else { return }
    self.wrappedValue = value
  }
}

extension CactusEnvironmentValues {
  fileprivate var hydrationKey: MemoryStore.Key {
    get { self[HydrationKey.self] }
    set { self[HydrationKey.self] = newValue }
  }

  private enum HydrationKey: Key {
    static let defaultValue = MemoryStore.Key(level: 0, index: 0)
  }
}
