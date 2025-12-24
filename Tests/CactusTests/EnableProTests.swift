import Cactus
import Testing

@Suite
struct `EnablePro tests` {
  @Test(.disabled(if: Secrets.current == nil))
  func `Can Enable Pro Successfully`() async throws {
    await #expect(throws: Never.self) {
      try await enablePro(key: Secrets.current!.proKey, deviceMetadata: .mock())
    }
  }
}
