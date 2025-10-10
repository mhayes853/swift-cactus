import IssueReporting
import Logging

// MARK: - CactusTelemetry

public enum CactusTelemetry {
  #if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
    public static var defaultClient: any Client & Sendable {
      SystemTelemetryClient.shared
    }

    @MainActor
    public static func configure(_ token: String) {
      Self.configure(token, deviceMetadata: .current, client: Self.defaultClient)
    }
  #endif

  #if canImport(Darwin)
    @MainActor
    public static func configure(_ token: String, client: any Client & Sendable) {
      Self.configure(token, deviceMetadata: .current, client: client)
    }
  #endif

  public static func configure(
    _ token: String,
    deviceMetadata: DeviceMetadata,
    client: any Client & Sendable,
    logger: Logger = Logger(label: "cactus.telemetry.configure")
  ) {
    let session = Session(client: client, token: token)
    Self.currentSession.withLock { $0 = session }
    Task {
      do {
        try await session.load(with: deviceMetadata)
      } catch {
        logger.error("Configuration Error", metadata: ["error": .string(String(describing: error))])
      }
    }
  }

  public static func send(
    event: any Event & Sendable,
    logger: Logger = Logger(label: "cactus.telemetry.send.event")
  ) {
    let session = Self.currentSession.withLock { $0 }
    Task {
      do {
        try await session?.send(event: event)
      } catch {
        logger.error(
          "Failed to send event.",
          metadata: ["error": .string(String(describing: error)), "event": "\(event)"]
        )
      }
    }
  }

  public static func registerDevice(
    _ metadata: DeviceMetadata,
    logger: Logger = Logger(label: "cactus.telemetry.register.device")
  ) {
    let session = Self.currentSession.withLock { $0 }
    guard let session else {
      reportIssue(
        """
        Attempted to register device without configuring telemetry.

            Device: \(metadata)

        Ensure that you have called `CactusTelemetry.configure` before registering the device.
        """
      )
      return
    }
    Task {
      do {
        try await session.registerDevice(metadata)
      } catch {
        logger.error(
          "Failed to register device.",
          metadata: ["error": .string(String(describing: error)), "device.metadata": "\(metadata)"]
        )
      }
    }
  }

  public static func reset() {
    Self.currentSession.withLock { $0 = nil }
  }
}

// MARK: - Session

extension CactusTelemetry {
  private static let currentSession = Lock<Session?>(nil)

  private final actor Session {
    private let client: any Client & Sendable
    private let token: String
    private var deviceId: CactusTelemetry.DeviceID?
    private var registerDeviceTask: Task<String, any Error>?

    init(client: any Client & Sendable, token: String) {
      self.client = client
      self.token = token
    }

    func load(with metadata: DeviceMetadata) async throws {
      self.deviceId = try await client.deviceId()
      guard self.deviceId == nil else { return }
      try await self.registerDevice(metadata)
    }

    func registerDevice(_ metadata: DeviceMetadata) async throws {
      self.registerDeviceTask?.cancel()
      self.registerDeviceTask = Task {
        let deviceId = try await self.client.registerDevice(metadata)
        self.deviceId = deviceId
        self.registerDeviceTask = nil
        return deviceId
      }
      _ = try await self.registerDeviceTask?.value
    }

    func send(event: any Event & Sendable) async throws {
      while let registerDeviceTask {
        _ = try? await registerDeviceTask.value
      }
      guard let deviceId else { return }
      let data = ClientEventData(deviceId: deviceId, token: self.token)
      try await self.client.send(event: event, with: data)
    }
  }
}
