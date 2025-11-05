import Cactus
import CustomDump
import Testing

@Suite
struct `CactusTelemetryProjectID tests` {
  @Test
  func `Project ID Is A UUIDV5`() {
    expectNoDifference(CactusTelemetry.projectId, "48033507-c78b-50fe-8fbb-9b1d41885367")
  }
}
