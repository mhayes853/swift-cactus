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
      event: CactusTelemetry.Event,
      token: String,
      deviceId: CactusTelemetry.DeviceID
    ) async throws {
      let event = self.supabaseEvent(event: event, token: token, deviceId: deviceId)
      try await self.client.send(events: [event])
    }

    private func supabaseEvent(
      event: CactusTelemetry.Event,
      token: String,
      deviceId: CactusTelemetry.DeviceID
    ) -> CactusSupabaseClient.TelemetryEvent {
      CactusSupabaseClient.TelemetryEvent(
        eventType: event.name,
        projectId: token,
        deviceId: deviceId,
        ttft: event.properties["ttft"] as? Double,
        tps: event.properties["tps"] as? Double,
        responseTime: event.properties["responseTime"] as? Double,
        model: event.properties["model"] as? String,
        tokens: event.properties["tokens"] as? Int,
        framework: event.framework,
        frameworkVersion: event.frameworkVersion,
        success: event.properties["success"] as? Bool,
        message: event.properties["message"] as? String,
        telemetryToken: event.properties["telemetryToken"] as? String,
        audioDuration: event.properties["audioDuration"] as? Int64,
        mode: event.properties["mode"] as? String
      )
    }
  }
#endif
