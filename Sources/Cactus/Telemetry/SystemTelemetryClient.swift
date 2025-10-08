private import _CactusUtils

final class SystemTelemetryClient: CactusTelemetry.Client, Sendable {
  static let shared = SystemTelemetryClient(client: .shared)

  private let client: CactusSupabaseClient

  init(client: CactusSupabaseClient) {
    self.client = client
  }

  func deviceId() async throws -> CactusTelemetry.DeviceID {
    ""
  }

  func registerDevice(
    _ metadata: CactusTelemetry.DeviceMetadata
  ) async throws -> CactusTelemetry.DeviceID {
    ""
  }

  func send(event: CactusTelemetry.Event) async throws {
  }
}
