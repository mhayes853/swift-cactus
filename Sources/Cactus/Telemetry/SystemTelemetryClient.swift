#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  import cactus_util

  final class SystemTelemetryClient: CactusTelemetry.Client, Sendable {
    static let shared = SystemTelemetryClient(client: .shared)

    private let client: CactusSupabaseClient

    init(client: CactusSupabaseClient) {
      self.client = client
    }

    func deviceId() async throws -> CactusTelemetry.DeviceID? {
      get_device_id().map { CactusTelemetry.DeviceID(cString: $0) }
    }

    func registerDevice(
      _ metadata: CactusTelemetry.DeviceMetadata
    ) async throws -> CactusTelemetry.DeviceID {
      let registration = CactusSupabaseClient.DeviceRegistration(deviceData: metadata)
      let payload = try await self.client.registerDevice(registration: registration)
      return CactusTelemetry.DeviceID(cString: register_app(payload))
    }

    func send(
      event: any CactusTelemetry.Event & Sendable,
      with data: CactusTelemetry.ClientEventData
    ) async throws {
      fatalError()
    }
  }
#endif
