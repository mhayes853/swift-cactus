#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  import Cactus
  import Testing

  @Suite
  struct `EnablePro tests` {
    @Test(.disabled(if: Secrets.current == nil))
    func `Can Enable Pro Successfully`() async throws {
      try await withBlankCactusUtilsDatabase {
        _ = await #expect(throws: Never.self) {
          try await enablePro(key: Secrets.current!.proKey, deviceMetadata: .mock())
        }
      }
    }
  }
#endif
