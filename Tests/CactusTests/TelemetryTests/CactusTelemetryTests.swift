import Cactus
import CustomDump
import Foundation
import Testing

@Suite(.serialized)
struct `CactusTelemetry tests` {
  init() async {
    await CactusTelemetry.disable()
  }

  @Test
  func `Reports Issue When Setup Called Twice`() async {
    CactusTelemetry.setup()
    withKnownIssue {
      CactusTelemetry.setup()
    }
    await CactusTelemetry.disable()
  }

  @Test
  func `Setup Can Be Called Again After Shutdown`() async {
    CactusTelemetry.setup()
    await CactusTelemetry.disable()
    CactusTelemetry.setup()
    await CactusTelemetry.disable()
  }

  @Test
  func `isActive Reflects Telemetry State`() async {
    expectNoDifference(CactusTelemetry.isActive, false)
    CactusTelemetry.setup()
    expectNoDifference(CactusTelemetry.isActive, true)
    await CactusTelemetry.disable()
    expectNoDifference(CactusTelemetry.isActive, false)
  }
}
