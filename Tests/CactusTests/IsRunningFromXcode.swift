import Foundation

var isRunningTestsFromXcode: Bool {
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
