import Cactus
import CustomDump
import Testing

@Suite
struct `MemoryBinding tests` {
  @Test
  func `Binding Derived From Memory Writes Back`() async throws {
    struct MemoryBackedAgent: CactusAgent {
      @Memory(.inMemory("count").scope(.session)) private var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
        IncrementAgent(count: self.$count.binding)
      }
    }

    let session = CactusAgenticSession(MemoryBackedAgent())
    let first = try await session.respond()
    let second = try await session.respond()

    expectNoDifference(first.output, 1)
    expectNoDifference(second.output, 2)

    let stored = session.scopedMemory.value(
      at: .inMemory("count").scope(.session),
      as: Int.self
    )
    expectNoDifference(stored, 2)
  }

  @Test
  func `Constant Binding Does Not Mutate`() async throws {
    let session = CactusAgenticSession(IncrementAgent(count: .constant(5)))

    let first = try await session.respond()
    let second = try await session.respond()

    expectNoDifference(first.output, 5)
    expectNoDifference(second.output, 5)
  }

  @Test
  func `Dynamic Member Binding Writes Through`() async throws {
    struct State: Sendable {
      var count: Int
    }

    struct StateAgent: CactusAgent {
      @Memory(.inMemory("state").scope(.session)) private var state = State(count: 0)

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
        IncrementAgent(count: self.$state.binding.count)
      }
    }

    let session = CactusAgenticSession(StateAgent())
    let resp = try await session.respond()

    expectNoDifference(resp.output, 1)
  }

  @Test
  func `Functional Binding Reads And Writes`() async throws {
    let state = Lock((value: 0, setValues: [Int]()))
    let binding = MemoryBinding<Int>(
      get: { state.withLock { $0.value } },
      set: { newValue in
        state.withLock {
          $0.setValues.append(newValue)
          $0.value = newValue
        }
      }
    )

    let session = CactusAgenticSession(IncrementAgent(count: binding))
    _ = try await session.respond()
    let second = try await session.respond()

    expectNoDifference(second.output, 2)
    expectNoDifference(state.withLock { $0.value }, 2)
    expectNoDifference(state.withLock { $0.setValues }, [1, 2])
  }

  @Test
  func `Unwrap Fails When Binding Is Nil`() {
    let unwrapped = MemoryBinding<Int>(MemoryBinding<Int?>.constant(nil))
    expectNoDifference(unwrapped == nil, true)
  }

  @Test
  func `Unwrap Succeeds When Binding Has Value`() {
    let unwrapped = MemoryBinding<Int>(MemoryBinding<Int?>.constant(5))
    expectNoDifference(unwrapped?.wrappedValue, 5)
  }

  @Test
  func `Unwrapped Binding Keeps Value When Base Becomes Nil`() {
    let baseState = Lock<Int?>(1)
    let optionalBinding = MemoryBinding<Int?>(
      get: { baseState.withLock { $0 } },
      set: { newValue in baseState.withLock { $0 = newValue } }
    )

    let unwrapped = MemoryBinding<Int>(optionalBinding)
    expectNoDifference(unwrapped?.wrappedValue, 1)

    optionalBinding.wrappedValue = nil
    unwrapped?.wrappedValue = 10

    expectNoDifference(optionalBinding.wrappedValue, nil)
    expectNoDifference(unwrapped?.wrappedValue, 10)
  }
}

private struct IncrementAgent: CactusAgent {
  @MemoryBinding var count: Int

  func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
    Run { _ in
      self.count += 1
      return self.count
    }
  }
}
