import Foundation

#if os(Android)
  import Crypto
#else
  import CryptoKit
#endif

// MARK: - Constants

extension UUID {
  static let `nil` = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

// MARK: - V5

extension UUID {
  static let urlNamespace = UUID(uuidString: "6ba7b811-9dad-11d1-80b4-00c04fd430c8")!

  static func v5(namespace: UUID, name: String) -> UUID {
    var ns = namespace.uuid
    let nsBytes = withUnsafeBytes(of: &ns) { Data($0) }
    var bytes = Data(Insecure.SHA1.hash(data: nsBytes + Data(name.utf8)).prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(uuid: bytes.withUnsafeBytes { $0.load(as: uuid_t.self) })
  }
}
