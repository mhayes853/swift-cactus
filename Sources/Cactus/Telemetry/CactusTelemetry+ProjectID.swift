import Foundation
import IssueReporting

extension CactusTelemetry {
  public static var projectId: String {
    let name = "swift-cactus/\(Self.mainBundleIdentifier)/v1"
    return UUID.v5(namespace: .urlNamespace, name: name).uuidString.lowercased()
  }

  private static var mainBundleIdentifier: String {
    isTesting ? "swift.cactus.test" : Bundle.main.bundleIdentifier ?? "unknown"
  }
}
