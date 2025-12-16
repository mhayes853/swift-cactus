import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgentSession tests` {
  @Test
  func `Basic Response`() async throws {
    let session = CactusAgenticSession(PassthroughAgent())
    let response = try await session.respond(to: "blob")
    expectNoDifference(response.output, "blob")
  }

  @Test
  func `Is Responding True When Responding`() async throws {
    let session = CactusAgenticSession(NeverAgent())

    expectNoDifference(session.isResponding, false)
    let task = Task { try await session.respond(to: "Blob") }
    await Task.megaYield()
    expectNoDifference(session.isResponding, true)
    task.cancel()
  }

  @Test
  func `Is Not Responding After Finishing Response`() async throws {
    let session = CactusAgenticSession(PassthroughAgent())
    _ = try await session.respond(to: "Blob")
    expectNoDifference(session.isResponding, false)
  }

  @Test
  func `Is Responding With Concurrent Streams`() async throws {
    let gate = ResponseGate()
    let session = CactusAgenticSession(BlockingAgent(gate: gate))

    let firstStream = session.stream(for: "First")
    let secondStream = session.stream(for: "Second")

    expectNoDifference(session.isResponding, true)

    await Task.megaYield()

    firstStream.stop()
    await Task.megaYield()
    expectNoDifference(session.isResponding, true)

    secondStream.stop()
    await Task.megaYield()
    expectNoDifference(session.isResponding, false)
  }

  #if canImport(Observation)
    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `Is Responding Observations`() async throws {
      let session = CactusAgenticSession(PassthroughAgent())

      let isResponding = Lock([Bool]())
      let token = observe {
        isResponding.withLock { $0.append(session.isResponding) }
      }
      _ = try await session.respond(to: "Message")

      await Task.megaYield()

      isResponding.withLock { expectNoDifference($0, [false, true, false]) }
      token.cancel()
    }
  #endif
}
