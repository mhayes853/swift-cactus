import CXXCactusShims
import Foundation

/// A logging interface for the Cactus engine.
///
/// ```swift
/// import Cactus
///
/// CactusLogging.setLevel(.debug)
/// CactusLogging.setHandler { entry in
///   print(entry.message)
/// }
/// CactusLogging.removeHandler()
/// ```
public enum CactusLogging {
  /// The severity level for log messages.
  ///
  /// Levels are ordered from most verbose (debug) to least verbose (none):
  /// - `debug`: All log messages.
  /// - `info`: Informational messages and above.
  /// - `warn`: Warnings and errors.
  /// - `error`: Errors only.
  /// - `none`: No log messages.
  public enum Level: Int32, Sendable, CaseIterable, CustomStringConvertible {
    /// Verbose debugging information.
    case debug = 0
    /// General informational messages.
    case info = 1
    /// Warning messages and errors.
    case warn = 2
    /// Error messages only.
    case error = 3
    /// Disables all logging.
    case none = 4

    public var description: String {
      switch self {
      case .debug: "DEBUG"
      case .info: "INFO"
      case .warn: "WARN"
      case .error: "ERROR"
      case .none: "NONE"
      }
    }
  }

  /// A log entry from the Cactus engine.
  public struct Entry: Sendable {
    /// The severity level of this entry.
    public let level: Level
    /// The component that generated this log message.
    public let component: String
    /// The log message text.
    public let message: String
  }

  /// Sets the minimum severity level for log messages.
  ///
  /// - Parameter level: The minimum level of messages to capture.
  public static func setLevel(_ level: Level) {
    cactus_log_set_level(level.rawValue)
  }

  /// Registers a handler to receive log messages from the Cactus engine.
  ///
  /// - Parameter handler: A closure that receives each log entry.
  public static func setHandler(_ handler: @escaping (Entry) -> Void) {
    let box = LogCallbackBox(handler)
    cactus_log_set_callback(logCallback, Unmanaged.passRetained(box).toOpaque())
  }

  /// Removes the currently registered log handler.
  public static func removeHandler() {
    cactus_log_set_callback(nil, nil)
  }
}

private final class LogCallbackBox: @unchecked Sendable {
  let callback: (CactusLogging.Entry) -> Void

  init(_ callback: @escaping (CactusLogging.Entry) -> Void) {
    self.callback = callback
  }
}

private func logCallback(
  level: Int32,
  component: UnsafePointer<CChar>?,
  message: UnsafePointer<CChar>?,
  userData: UnsafeMutableRawPointer?
) {
  guard let userData, let component, let message else { return }
  let box = Unmanaged<LogCallbackBox>.fromOpaque(userData).takeUnretainedValue()
  let entry = CactusLogging.Entry(
    level: CactusLogging.Level(rawValue: level) ?? .info,
    component: String(cString: component),
    message: String(cString: message)
  )
  box.callback(entry)
}
