extension CactusTelemetry {
  public typealias DeviceID = String

  public struct ClientEventData: Sendable {
    public let deviceId: DeviceID
    public let token: String
    public let projectId: String
  }

  public protocol Client {
    func deviceId() async throws -> DeviceID?
    func registerDevice(_ metadata: DeviceMetadata) async throws -> DeviceID
    func send(event: any Event & Sendable, with data: ClientEventData) async throws
  }
}
