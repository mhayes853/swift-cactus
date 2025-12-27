import Cactus
import Foundation

extension CactusDeviceMetadata {
  static func mock() -> Self {
    Self(model: "mac", os: "macOS", osVersion: "26.1", deviceId: UUID().uuidString, brand: "Apple")
  }
}
