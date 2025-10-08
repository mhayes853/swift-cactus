import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(WatchKit)
  import WatchKit
#elseif canImport(IOKit)
  import IOKit
#endif

extension CactusTelemetry {
  /// Device info for telemetry.
  public struct DeviceMetadata: Hashable, Sendable, Codable {
    /// The name of the device.
    public var name: String

    /// The operating system of the device.
    public var os: String

    /// A stringified os version of the device.
    public var osVersion: String

    /// A device vendor id.
    public var deviceId: String

    /// The brand that owns the device.
    public var brand: String

    /// Creates device metadata.
    ///
    /// - Parameters:
    ///   - name: The name of the device.
    ///   - os: The operating system of the device.
    ///   - osVersion: A stringified os version of the device.
    ///   - deviceId: A device vendor id.
    ///   - brand: The brand that owns the device.
    public init(name: String, os: String, osVersion: String, deviceId: String, brand: String) {
      self.name = name
      self.os = os
      self.osVersion = osVersion
      self.deviceId = deviceId
      self.brand = brand
    }
  }
}

#if canImport(Darwin)
  extension CactusTelemetry.DeviceMetadata {
    @MainActor
    public static var current: Self {
      #if os(iOS) || os(tvOS) || os(visionOS)
        let device = UIDevice.current
        return Self(
          name: device.name,
          os: device.systemName,
          osVersion: device.systemVersion,
          deviceId: device.identifierForVendor.map(\.uuidString) ?? "unknown",
          brand: "Apple"
        )
      #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        var deviceId = "unknown"
        if #available(watchOS 6.2, *), let id = device.identifierForVendor {
          deviceId = id.uuidString
        }
        return Self(
          name: device.name,
          os: device.systemName,
          osVersion: device.systemVersion,
          deviceId: deviceId,
          brand: "Apple"
        )
      #else
        let hostName = Host.current().localizedName ?? "Mac"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        return Self(
          name: hostName,
          os: "macOS",
          osVersion: osVersion,
          deviceId: Self.hardwareDeviceId,
          brand: "Apple"
        )
      #endif
    }

    #if canImport(IOKit)
      private static var hardwareDeviceId: String {
        let service = IOServiceGetMatchingService(
          kIOMasterPortDefault,
          IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { if service != 0 { IOObjectRelease(service) } }
        guard service != 0,
          let cfValue = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
          )?
          .takeRetainedValue() as? String
        else { return "unknown" }
        return cfValue
      }
    #endif
  }
#endif
