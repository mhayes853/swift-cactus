#if canImport(Darwin)
  import Foundation

  extension URL {
    static var _applicationSupportDirectory: URL {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        .applicationSupportDirectory
      } else {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      }
    }
  }
#endif
