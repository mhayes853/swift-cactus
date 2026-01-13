// MARK: - DeviceID

extension CactusTelemetry {
  /// An id for a device tracked by cactus telemetry.
  public typealias DeviceID = String
}

// MARK: - ClientEventData

extension CactusTelemetry {
  /// Necessary data for sending telemetry events.
  public struct ClientEventData: Sendable {
    /// The ``CactusTelemetry/DeviceID`` of the current device.
    public let deviceId: DeviceID

    /// The telemetry token from the cactus dashboard.
    public let token: String

    /// The project id to send with events.
    public let projectId: String
  }
}

// MARK: - Client

extension CactusTelemetry {
  /// A protocol for sending cactus telemetry events.
  public protocol Client {
    /// Returns the current registered ``CactusTelemetry/DeviceID`` if known.
    func deviceId() async throws -> DeviceID?

    /// Registers a device for cactus telemetry.
    ///
    /// - Parameter metadata: The ``CactusTelemetry/DeviceMetadata`` of the device.
    /// - Returns: The registered ``CactusTelemetry/DeviceID``.
    func registerDevice(_ metadata: DeviceMetadata) async throws -> DeviceID

    /// Sends a telemetry ``CactusTelemetry/Event``.
    ///
    /// - Parameters:
    ///   - event: The event to send.
    ///   - data: The ``CactusTelemetry/ClientEventData`` associated with the event.
    func send(event: any Event & Sendable, with data: ClientEventData) async throws
  }
}
