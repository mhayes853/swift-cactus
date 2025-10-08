extension CactusTelemetry {
  public typealias DeviceID = String

  public protocol Client {
    func deviceId() async throws -> DeviceID
    func registerDevice(_ metadata: DeviceMetadata) async throws -> DeviceID
    func send(event: Event) async throws
  }
}
