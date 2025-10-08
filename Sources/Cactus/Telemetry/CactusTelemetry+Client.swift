extension CactusTelemetry {
  public protocol Client {
    func send(event: Event) async throws
  }
}
