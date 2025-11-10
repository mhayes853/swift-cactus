import Cactus
import CustomDump
import Testing

@Suite
struct `CactusTelemetryProjectID tests` {
  @Test
  func `Project ID Is A UUIDV5`() {
    // NB: Xcode uses a different Bundle ID than SPM CLI.
    if !isRunningTestsFromXcode {
      expectNoDifference(CactusTelemetry.projectId, "48033507-c78b-50fe-8fbb-9b1d41885367")
    } else {
      expectNoDifference(CactusTelemetry.projectId, "fc6e9e17-8789-5155-bd59-ab433c812fdb")
    }
  }
}
