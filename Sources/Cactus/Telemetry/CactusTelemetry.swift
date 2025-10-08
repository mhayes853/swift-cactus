public enum CactusTelemetry {
  public static var defaultClient: any Client {
    SystemTelemetryClient.shared
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
    Self.registerDevice(deviceMetadata)
  }

  public static func send(event: Event) {

  }

  public static func registerDevice(_ metadata: DeviceMetadata) {

  }
}
