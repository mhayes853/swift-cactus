#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  import cactus_util

  // MARK: - DefaultClient

  extension CactusTelemetry {
    public final class DefaultClient: Client, Sendable {
      static let shared = DefaultClient(client: .shared)

      private let client: CactusSupabaseClient

      init(client: CactusSupabaseClient) {
        self.client = client
      }

      public func deviceId() async throws -> CactusTelemetry.DeviceID? {
        get_device_id().map { CactusTelemetry.DeviceID(cString: $0) }
      }

      public func registerDevice(
        _ metadata: CactusTelemetry.DeviceMetadata
      ) async throws -> CactusTelemetry.DeviceID {
        let registration = CactusSupabaseClient.DeviceRegistration(deviceData: metadata)
        let payload = try await self.client.registerDevice(registration: registration)
        return CactusTelemetry.DeviceID(cString: register_app(payload))
      }

      public func send(
        event: any CactusTelemetry.Event & Sendable,
        with data: CactusTelemetry.ClientEventData
      ) async throws {
        guard let event = self.supabaseTelemetryEvent(from: event, data: data) else { return }
        try await self.client.send(events: [event])
      }

      private func supabaseTelemetryEvent(
        from event: any CactusTelemetry.Event,
        data: CactusTelemetry.ClientEventData
      ) -> CactusSupabaseClient.TelemetryEvent? {
        switch event {
        case let event as CactusTelemetry.LanguageModelCompletionEvent:
          CactusSupabaseClient.TelemetryEvent(
            eventType: event.name,
            projectId: data.projectId,
            deviceId: data.deviceId,
            ttft: event.chatCompletion.timeIntervalToFirstToken * 1000,
            tps: event.chatCompletion.tokensPerSecond,
            responseTime: event.chatCompletion.totalTimeInterval,
            model: event.configuration.modelSlug,
            tokens: event.chatCompletion.totalTokens,
            framework: frameworkName,
            frameworkVersion: swiftCactusVersion,
            success: true,
            message: nil,
            telemetryToken: data.token,
            audioDuration: nil,
            mode: "LOCAL"
          )
        case let event as CactusTelemetry.LanguageModelEmbeddingsEvent:
          CactusSupabaseClient.TelemetryEvent(
            eventType: event.name,
            projectId: data.projectId,
            deviceId: data.deviceId,
            ttft: nil,
            tps: nil,
            responseTime: nil,
            model: event.configuration.modelSlug,
            tokens: nil,
            framework: frameworkName,
            frameworkVersion: swiftCactusVersion,
            success: true,
            message: nil,
            telemetryToken: data.token,
            audioDuration: nil,
            mode: nil
          )
        case let event as CactusTelemetry.LanguageModelInitEvent:
          CactusSupabaseClient.TelemetryEvent(
            eventType: event.name,
            projectId: data.projectId,
            deviceId: data.deviceId,
            ttft: nil,
            tps: nil,
            responseTime: nil,
            model: event.configuration.modelSlug,
            tokens: nil,
            framework: frameworkName,
            frameworkVersion: swiftCactusVersion,
            success: true,
            message: nil,
            telemetryToken: data.token,
            audioDuration: nil,
            mode: nil
          )
        case let event as CactusTelemetry.LanguageModelErrorEvent:
          CactusSupabaseClient.TelemetryEvent(
            eventType: event.name,
            projectId: data.projectId,
            deviceId: data.deviceId,
            ttft: nil,
            tps: nil,
            responseTime: nil,
            model: event.configuration.modelSlug,
            tokens: nil,
            framework: frameworkName,
            frameworkVersion: swiftCactusVersion,
            success: false,
            message: event.message,
            telemetryToken: data.token,
            audioDuration: nil,
            mode: nil
          )
        default:
          nil
        }
      }
    }
  }

  extension CactusTelemetry.Client where Self == CactusTelemetry.DefaultClient {
    public static var `default`: Self { .shared }
  }

  // MARK: - Helpers

  private let frameworkName = "swift-cactus"
#endif
