import Foundation

#if SwiftCactusTOON
  import ToonFormat
#endif

// MARK: - TopLevelEncoder

public protocol TopLevelDecoder<Encoded> {
  associatedtype Encoded
  func decode<T: Decodable>(_ type: T.Type, from encoded: Encoded) throws -> T
}

// MARK: - Conformances

extension JSONDecoder: TopLevelDecoder {}
extension PropertyListDecoder: TopLevelDecoder {}

#if SwiftCactusTOON
  extension TOONDecoder: TopLevelDecoder {}
#endif
