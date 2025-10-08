// MARK: - CactusTelemetry

public enum CactusTelemetry {
  public static var defaultClient: any Client {
    fatalError()
  }

  #if canImport(Darwin)
    @MainActor
    public static func configure(
      _ token: String,
      client: sending any Client = Self.defaultClient
    ) {
      Self.configure(token, deviceMetadata: .current, client: client)
    }
  #endif
  
  public static func configure(
    _ token: String,
    deviceMetadata: DeviceMetadata,
    client: sending any Client = Self.defaultClient
  ) {

  }

  public static func send(event: Event) {

  }
}

// MARK: - Event

extension CactusTelemetry {
  public struct Event: Hashable, Sendable, Codable {
    public let eventType: String
    public let projectId: String?
    public let deviceId: String?
    public let ttft: Double?
    public let tps: Double?
    public let responseTime: Double?
    public let model: String?
    public let tokens: Int?
    public let framework: String
    public let frameworkVersion: String
    public let success: Bool?
    public let message: String?
    public let telemetryToken: String?
    public let audioDuration: Int64?
    public let mode: String?

    private init(
      eventType: String,
      projectId: String? = nil,
      deviceId: String? = nil,
      ttft: Double? = nil,
      tps: Double? = nil,
      responseTime: Double? = nil,
      model: String? = nil,
      tokens: Int? = nil,
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
      self.frameworkVersion = frameworkVersion
      self.success = success
      self.message = message
      self.telemetryToken = telemetryToken
      self.audioDuration = audioDuration
      self.mode = mode
      self.framework = "swift-cactus"
    }
  }
}
