private import _CactusUtils

final class SupabaseTelemetryClient: CactusTelemetry.Client {
  private let client: CactusSupabaseClient

  init(client: CactusSupabaseClient) {
    self.client = client
  }

  nonisolated(nonsending) func send(event: CactusTelemetry.Event) async throws {
  }
}
