extension CactusTelemetry {
  public struct Event: Sendable {
    public let name: String
    public var framework: String { "swift-cactus" }
    public var frameworkVersion: String { swiftCactusVersion }
    public var properties: [String: any Sendable]

    public init(name: String, properties: [String: any Sendable] = [:]) {
      self.name = name
      self.properties = properties
    }
  }
}
