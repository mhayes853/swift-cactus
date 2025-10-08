extension CactusTelemetry {
  public protocol Client {
    nonisolated(nonsending) func send(event: Event) async throws
  }
}
