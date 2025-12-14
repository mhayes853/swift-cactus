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

// MARK: - AnyTopLevelDecoder

public struct AnyTopLevelDecoder<Encoded>: TopLevelDecoder {
  private let decoder: any TopLevelDecoder<Encoded>

  public init(_ decoder: any TopLevelDecoder<Encoded>) {
    self.decoder = decoder
  }

  public func decode<T: Decodable>(_ type: T.Type, from encoded: Encoded) throws -> T {
    try self.decoder.decode(type, from: encoded)
  }
}
