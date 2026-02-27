import Foundation

/// Sets the Cactus API key for hybrid (local + cloud) inference.
///
/// > Warning: Avoid hardcoding credentials on a client-side app that's widely distributed.
/// > Attackers can inspect your binary or app's network traffic through a debugger to extract
/// > the key.
///
/// - Parameter apiKey: The API key for Cactus Cloud hybrid cloud access.
public func setAPIKey(_ apiKey: String) {
  setenv("CACTUS_CLOUD_KEY", apiKey, 1)
}
