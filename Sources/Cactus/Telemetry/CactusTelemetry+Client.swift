extension CactusTelemetry {
  public protocol Client {
    nonisolated(nonsending) func registerDevice(id: String) async throws
    nonisolated(nonsending) func send(event: Event) async throws
  }
}
