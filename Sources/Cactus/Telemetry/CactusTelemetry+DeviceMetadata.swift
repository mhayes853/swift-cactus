#if canImport(SwiftUI)
  import SwiftUI
#endif

#if canImport(UIKit)
  import UIKit
#elseif canImport(WatchKit)
  import WatchKit
#elseif canImport(IOKit)
  import IOKit
#endif

// MARK: - DeviceMetadata

extension CactusTelemetry {
  /// Device info for telemetry.
  public struct DeviceMetadata: Hashable, Sendable, Codable {
    /// The model name of the device.
    public var model: String

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
    ///   - model: The model name of the device.
    ///   - os: The operating system of the device.
    ///   - osVersion: A stringified os version of the device.
    ///   - deviceId: A device vendor id.
    ///   - brand: The brand that owns the device.
    public init(model: String, os: String, osVersion: String, deviceId: String, brand: String) {
      self.model = model
      self.os = os
      self.osVersion = osVersion
      self.deviceId = deviceId
      self.brand = brand
    }

    private enum CodingKeys: String, CodingKey {
      case model
      case os
      case osVersion = "os_version"
      case deviceId = "device_id"
      case brand
    }
  }
}

// MARK: - Current Metadata

#if canImport(Darwin)
  extension CactusTelemetry.DeviceMetadata {
    /// The current telemetry device metadata.
    @MainActor
    public static var current: Self {
      #if os(iOS) || os(tvOS) || os(visionOS)
        let device = UIDevice.current
        return Self(
          model: Self.hardwareModelName,
          os: device.systemName,
          osVersion: Self.osVersionString,
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
          model: Self.hardwareModelName,
          os: device.systemName,
          osVersion: Self.osVersionString,
          deviceId: deviceId,
          brand: "Apple"
        )
      #else
        return Self(
          model: Self.hardwareModelName,
          os: "macOS",
          osVersion: Self.osVersionString,
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
        defer { IOObjectRelease(service) }
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

    private static var osVersionString: String {
      let osVersion = ProcessInfo.processInfo.operatingSystemVersion
      return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    private static var hardwareModelName: String {
      #if targetEnvironment(simulator)
        let modelName =
          ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?.description
          ?? "Unknown"
        return "\(modelName) (Simulator)"
      #else
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let bytes = model.compactMap { $0 == 0 ? nil : UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
      #endif
    }
  }
#endif
