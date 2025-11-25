import Foundation

#if SwiftCactusTOON
  import TOONEncoder
#endif

// MARK: - TopLevelEncoder

public protocol TopLevelEncoder<Output> {
  associatedtype Output
  func encode<T: Encodable>(_ value: T) throws -> Output
}

// MARK: - Conformances

extension JSONEncoder: TopLevelEncoder {}
extension PropertyListEncoder: TopLevelEncoder {}

#if SwiftCactusTOON
  extension TOONEncoder: TopLevelEncoder {}
#endif
