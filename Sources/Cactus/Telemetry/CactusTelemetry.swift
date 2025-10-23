import IssueReporting
import Logging

// MARK: - CactusTelemetry

/// A namespace for telemetry.
///
/// You can configure telemetry in the entry point of your app.
///
/// ```swift
/// import Cactus
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///   init() {
///     CactusTelemetry.configure("token-from-cactus-dashboard")
///   }
///
///   // ...
/// }
/// ```
///
/// ``CactusLanguageModel`` will automatically record telemetry events for every model
/// initialization, chat completion, and emdeddings generation. You can view the telemetry data
/// in the cactus dashboard.
public enum CactusTelemetry {
  #if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
    /// Configures telemetry with the specified token and default client.
    ///
    /// - Parameters:
    ///   - token: The telemetry token from the cactus dashboard.
    ///   - logger: The logger to use for configuration.
    @MainActor
    public static func configure(
      _ token: String,
      logger: Logger = Logger(label: "cactus.telemetry.configure")
    ) {
      Self.configure(token, deviceMetadata: .current, client: .default, logger: logger)
    }
  #endif

  #if canImport(Darwin)
    /// Configures telemetry with the specified token and client.
    ///
    /// - Parameters:
    ///   - token: The telemetry token from the cactus dashboard.
    ///   - client: The ``Client`` to use.
    ///   - logger: The logger to use for configuration.
    @MainActor
    public static func configure(
      _ token: String,
      client: any Client & Sendable,
      logger: Logger = Logger(label: "cactus.telemetry.configure")
    ) {
      Self.configure(token, deviceMetadata: .current, client: client, logger: logger)
    }
  #endif

  /// Configures telemetry with the specified token, device metadata, and client.
  ///
  /// - Parameters:
  ///   - token: The telemetry token from the cactus dashboard.
  ///   - deviceMetadata: The ``DeviceMetadata`` of the current device.
  ///   - client: The ``Client`` to use.
  ///   - logger: The logger to use for configuration.
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

  /// Sends a telemetry ``CactusTelemetry/Event``.
  ///
  /// - Parameters:
  ///   - event: The event to send.
  ///   - logger: The logger to use for this sending an event.
  public static func send(
    _ event: any Event & Sendable,
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

  /// Registers the specified ``DeviceMetadata``.
  ///
  /// Calling ``configure(_:logger:)`` will register the current device information automatically.
  ///
  /// - Parameters:
  ///   - metadata: The ``DeviceMetadata`` of the device.
  ///   - logger: The logger to use for registering a device.
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

  /// Resets all telemetry.
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
      let data = ClientEventData(
        deviceId: deviceId,
        token: self.token,
        projectId: CactusTelemetry.projectId
      )
      try await self.client.send(event: event, with: data)
    }
  }
}
