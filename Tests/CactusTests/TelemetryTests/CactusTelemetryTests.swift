import Cactus
import Foundation
import Testing

@Suite
struct `CactusTelemetry tests` {
  @Test
  func `Reports Issue When Setup Called Twice`() {
    let cacheLocation = FileManager.default.temporaryDirectory

    CactusTelemetry.setup()
    withKnownIssue {
      CactusTelemetry.setup()
    }
  }
}
