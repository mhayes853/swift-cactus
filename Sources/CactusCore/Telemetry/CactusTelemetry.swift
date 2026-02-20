import CXXCactusShims
import Foundation
import IssueReporting

/// Utilities for configuring Cactus telemetry.
public enum CactusTelemetry {
  private static let isSetup = Lock(false)

  /// Configures telemetry environment metadata.
  ///
  /// - Parameter cacheLocation: The model cache location.
  public static func setup(cacheLocation: URL) {
    let isSetup = Self.isSetup.withLock { isSetup in
      if isSetup {
        return true
      }
      isSetup = true
      return false
    }

    guard !isSetup else {
      reportIssue("Cactus telemetry has already been setup.")
      return
    }

    cactus_set_telemetry_environment("swift", cacheLocation.nativePath)
  }

  #if canImport(Darwin)
    /// Configures telemetry using the app caches directory.
    public static func setup() {
      let cacheLocation = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      guard let cacheLocation  else { return }
      Self.setup(cacheLocation: cacheLocation)
    }
  #endif
}
