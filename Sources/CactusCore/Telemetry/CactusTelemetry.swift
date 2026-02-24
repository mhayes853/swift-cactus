import CXXCactusShims
import Foundation
import IssueReporting

/// Utilities for configuring Cactus telemetry.
public enum CactusTelemetry {
  private static let isSetup = Lock(false)

  /// Whether telemetry is currently active.
  public static var isActive: Bool {
    Self.isSetup.withLock { $0 }
  }

  /// Enables telemetry at the specified `cacheLocation` directory.
  ///
  /// - Parameter cacheLocation: The directory for the telemetry cache.
  public static func setup(cacheLocation: URL) {
    let alreadySetup = Self.isSetup.withLock { alreadySetup in
      if alreadySetup {
        reportIssue("Cactus telemetry has already been setup.")
        return true
      }
      alreadySetup = true
      return false
    }

    guard !alreadySetup else { return }

    cactus_set_telemetry_environment("swift", cacheLocation.nativePath)
  }

  #if canImport(Darwin)
    /// Enables telemetry.
    public static func setup() {
      let cacheLocation = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent(".cactus-telemetry")
      guard let cacheLocation else { return }
      try? FileManager.default.createDirectory(at: cacheLocation, withIntermediateDirectories: true)
      Self.setup(cacheLocation: cacheLocation)
    }
  #endif

  /// Flushes any pending telemetry data.
  @concurrent
  public static func flush() async {
    cactus_telemetry_flush()
  }

  /// Disables telemetry.
  ///
  /// This will flush any pending telemetry data before fully disabling.
  @concurrent
  public static func disable() async {
    cactus_telemetry_shutdown()
    Self.isSetup.withLock { $0 = false }
  }
}
