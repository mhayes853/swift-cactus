#if canImport(FoundationEssentials)
  import FoundationEssentials
#else
  import Foundation
#endif

extension URL {
  package var nativePath: String {
    self.withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }
}
