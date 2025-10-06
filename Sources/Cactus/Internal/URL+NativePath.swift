#if canImport(FoundationEssentials)
  import FoundationEssentials
#else
  import Foundation
#endif

extension URL {
  var nativePath: String {
    withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }
}
