import Cactus
import CustomDump
import Testing

@Suite
struct `CactusTelemetry+ProjectID tests` {
  func `Project ID Is A UUIDV5`() {
    expectNoDifference(CactusTelemetry.projectId, "fc6e9e17-8789-5155-bd59-ab433c812fdb")
  }
}
