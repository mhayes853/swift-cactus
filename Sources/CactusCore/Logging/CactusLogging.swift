import CXXCactusShims
import Foundation

final class LogCallbackBox: @unchecked Sendable {
  let callback: (CactusLogging.Entry) -> Void

  init(_ callback: @escaping (CactusLogging.Entry) -> Void) {
    self.callback = callback
  }
}

private func logCallbackThunk(
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

/// A logging interface for the Cactus engine.
///
/// Use `CactusLogging` to control log verbosity and receive log messages from the
/// underlying C++ engine. This is useful for debugging and monitoring engine behavior.
///
/// ```swift
/// import Cactus
///
/// // Set the minimum log level to capture
/// CactusLogging.setLevel(.debug)
///
/// // Register a handler to receive log messages
/// CactusLogging.setHandler { entry in
///   print(entry.description)
/// }
///
/// // Remove the handler when no longer needed
/// CactusLogging.removeHandler()
/// ```
public enum CactusLogging {
  /// The severity level for log messages.
  ///
  /// Levels are ordered from most verbose (debug) to least verbose (none):
  /// - `debug`: All log messages
  /// - `info`: Informational messages and above
  /// - `warn`: Warnings and errors (default)
  /// - `error`: Errors only
  /// - `none`: No log messages
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
      case .debug: return "DEBUG"
      case .info: return "INFO"
      case .warn: return "WARN"
      case .error: return "ERROR"
      case .none: return "NONE"
      }
    }
  }

  /// A single log entry from the Cactus engine.
  ///
  /// Contains the severity level, source component, and message text.
  public struct Entry: Sendable {
    /// The severity level of this entry.
    public let level: Level
    /// The component that generated this log message (e.g., "Engine", "Index", "VAD").
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
  ///
  /// The handler is called synchronously from the engine's logging thread,
  /// so any heavy processing should be dispatched to a background queue.
  public static func setHandler(_ handler: @escaping (Entry) -> Void) {
    let box = LogCallbackBox(handler)
    cactus_log_set_callback(logCallbackThunk, Unmanaged.passRetained(box).toOpaque())
  }

  /// Removes the currently registered log handler.
  ///
  /// After calling this method, log messages will be discarded.
  public static func removeHandler() {
    cactus_log_set_callback(nil, nil)
  }
}
