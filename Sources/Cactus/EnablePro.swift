#if canImport(Darwin)
  /// Enables Cactus Pro asynchronously.
  ///
  /// You'll want to set this key when your application launches initially. The engine will
  /// automatically detect the key to enable NPU acceleration.
  /// ```swift
  /// import Cactus
  ///
  /// Task { try await enablePro(key: "your_pro_key_here") }
  /// ```
  @MainActor
  public func enablePro(key: String) async throws {
    try await enablePro(key: key, deviceMetadata: .current)
  }
#endif

/// Enables Cactus Pro asynchronously.
///
/// You'll want to set this key when your application launches initially. The engine will
/// automatically detect the key to enable NPU acceleration.
/// ```swift
/// import Cactus
///
/// let metadata = CactusDeviceMetadata(/* ... */)
/// Task { try await enablePro(key: "your_pro_key_here", deviceMetadata: metadata) }
/// ```
public func enablePro(key: String, deviceMetadata: CactusDeviceMetadata) async throws {
  #if canImport(cactus_util)
    try await CactusDeviceRegistration.shared.enablePro(key: key, deviceMetadata: deviceMetadata)
  #else
    struct ProNotSupportedOnPlatform: Error {}
    throw ProNotSupportedOnPlatform()
  #endif
}
