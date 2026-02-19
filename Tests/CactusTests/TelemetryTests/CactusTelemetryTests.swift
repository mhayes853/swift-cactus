import Cactus
import Foundation
import Testing

@Suite
struct `CactusTelemetry tests` {
  @Test
  func `Reports Issue When Setup Called Twice`() {
    CactusTelemetry.setup()
    withKnownIssue {
      CactusTelemetry.setup()
    }
  }
}
