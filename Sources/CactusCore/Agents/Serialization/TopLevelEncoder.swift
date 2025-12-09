import Foundation

#if SwiftCactusTOON
  import ToonFormat
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

// MARK: - SendableTopLevelJSONEncoder

@available(macOS, deprecated: 13, message: "Use JSONEncoder directly instead")
@available(iOS, deprecated: 16, message: "Use JSONEncoder directly instead")
@available(tvOS, deprecated: 16, message: "Use JSONEncoder directly instead")
@available(watchOS, deprecated: 9, message: "Use JSONEncoder directly instead")
public final class SendableTopLevelJSONEncoder: TopLevelEncoder & Sendable {
  private let encoder: Lock<JSONEncoder>

  public init(_ encoder: sending JSONEncoder) {
    self.encoder = Lock(encoder)
  }

  public func encode<T>(_ value: T) throws -> Data where T: Encodable {
    try self.encoder.withLock { try $0.encode(value) }
  }
}
