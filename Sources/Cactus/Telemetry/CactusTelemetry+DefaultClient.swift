#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  private import cactus_util
  import Foundation
  import IssueReporting

  // MARK: - DefaultClient

  extension CactusTelemetry {
    /// The default telemetry client.
    public final class DefaultClient: Client, Sendable {
      static let shared = DefaultClient(client: .shared)

      private let client: CactusSupabaseClient
      private let batcher: CactusTelemetry.Batcher

      init(client: CactusSupabaseClient) {
        self.client = client
        self.batcher = CactusTelemetry.Batcher(fileURL: .telemetryBatch()) { batch in
          try await client.send(events: batch)
        }
      }

      public func deviceId() async throws -> CactusTelemetry.DeviceID? {
        get_device_id(nil).map { CactusTelemetry.DeviceID(cString: $0) }
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
        try await self.batcher.record(event: event)
      }

      private func supabaseTelemetryEvent(
        from event: any CactusTelemetry.Event,
        data: CactusTelemetry.ClientEventData
      ) -> CactusTelemetry.Batcher.Event? {
        switch event {
        case let event as CactusTelemetry.LanguageModelCompletionEvent:
          CactusTelemetry.Batcher.Event(
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
        case let event as CactusTelemetry.LanguageModelTranscriptionEvent:
          CactusTelemetry.Batcher.Event(
            eventType: event.name,
            projectId: data.projectId,
            deviceId: data.deviceId,
            ttft: event.transcription.timeIntervalToFirstToken * 1000,
            tps: event.transcription.tokensPerSecond,
            responseTime: event.transcription.totalTimeInterval,
            model: event.configuration.modelSlug,
            tokens: event.transcription.totalTokens,
            framework: frameworkName,
            frameworkVersion: swiftCactusVersion,
            success: true,
            message: nil,
            telemetryToken: data.token,
            audioDuration: nil,
            mode: "LOCAL"
          )
        case let event as CactusTelemetry.LanguageModelEmbeddingsEvent:
          CactusTelemetry.Batcher.Event(
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
          CactusTelemetry.Batcher.Event(
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
          CactusTelemetry.Batcher.Event(
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
    /// The default telemetry client.
    public static var `default`: Self { .shared }
  }

  // MARK: - Helpers

  private let frameworkName = "swift-cactus"

  extension URL {
    fileprivate static func telemetryBatch() -> Self {
      guard !isTesting else {
        return FileManager.default.temporaryDirectory.appendingPathComponent(
          "__test-cactus-telemetry-batch-\(UUID())__.json"
        )
      }
      return URL._applicationSupportDirectory.appendingPathComponent("cactus-telemetry/batch.json")
    }
  }
#endif
