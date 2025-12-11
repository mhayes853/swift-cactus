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
