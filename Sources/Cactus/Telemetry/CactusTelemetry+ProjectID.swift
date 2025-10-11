import Foundation
import IssueReporting

extension CactusTelemetry {
  /// The telemetry project id for the current project.
  public static var projectId: String {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
    let name = "swift-cactus/\(bundleIdentifier)/v1"
    return UUID.v5(namespace: .urlNamespace, name: name).uuidString.lowercased()
  }
}
