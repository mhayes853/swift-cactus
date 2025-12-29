import Foundation

// MARK: - Batcher

extension CactusTelemetry {
  package final actor Batcher {
    private let fileURL: URL
    private let sendBatch: @Sendable ([Event]) async throws -> Void
    private var sendTask: Task<Void, any Error>?

    package init(
      fileURL: URL,
      sendBatch: @escaping @Sendable ([Event]) async throws -> Void
    ) {
      self.fileURL = fileURL
      self.sendBatch = sendBatch
    }

    package func record(event: Event) async throws {
      while let sendTask {
        _ = try? await sendTask.value
      }
      self.sendTask = Task {
        defer { self.sendTask = nil }
        var batch =
          (try? JSONDecoder().decode([Event].self, from: Data(contentsOf: self.fileURL))) ?? []
        batch.append(event)

        do {
          try await self.sendBatch(batch)
          batch = []
          try JSONEncoder().encode(batch).write(to: self.fileURL)
        } catch {
          try JSONEncoder().encode(batch).write(to: self.fileURL)
          throw error
        }
      }
      try await self.sendTask?.value
    }
  }
}

// MARK: - Event

extension CactusTelemetry.Batcher {
  package struct Event: Hashable, Sendable, Codable {
    package let eventType: String
    package let projectId: String?
    package let deviceId: String?
    package let ttft: Double?
    package let tps: Double?
    package let responseTime: Double?
    package let model: String?
    package let tokens: Int?
    package let framework: String
    package let frameworkVersion: String
    package let success: Bool?
    package let message: String?
    package let telemetryToken: String?
    package let audioDuration: Int64?
    package let mode: String?

    package init(
      eventType: String,
      projectId: String? = nil,
      deviceId: String? = nil,
      ttft: Double? = nil,
      tps: Double? = nil,
      responseTime: Double? = nil,
      model: String? = nil,
      tokens: Int? = nil,
      framework: String,
      frameworkVersion: String,
      success: Bool? = nil,
      message: String? = nil,
      telemetryToken: String? = nil,
      audioDuration: Int64? = nil,
      mode: String? = nil
    ) {
      self.eventType = eventType
      self.projectId = projectId
      self.deviceId = deviceId
      self.ttft = ttft
      self.tps = tps
      self.responseTime = responseTime
      self.model = model
      self.tokens = tokens
      self.framework = framework
      self.frameworkVersion = frameworkVersion
      self.success = success
      self.message = message
      self.telemetryToken = telemetryToken
      self.audioDuration = audioDuration
      self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
      case eventType = "event_type"
      case projectId = "project_id"
      case deviceId = "device_id"
      case ttft = "ttft"
      case tps = "tps"
      case responseTime = "response_time"
      case model = "model"
      case tokens = "tokens"
      case framework = "framework"
      case frameworkVersion = "framework_version"
      case success = "success"
      case message = "message"
      case telemetryToken = "telemetry_token"
      case audioDuration = "audio_duration"
      case mode = "mode"
    }
  }
}
