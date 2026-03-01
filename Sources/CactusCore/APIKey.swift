import Foundation

/// The Cactus Cloud API key for hybrid (local + cloud) inference.
///
/// This value is stored in the `CACTUS_CLOUD_KEY` environment variable.
///
/// > Warning: Avoid hardcoding credentials on a client-side app that's publicly distributed.
/// > Attackers can inspect your binary or app's network traffic through a debugger to extract
/// > the key.
public var cactusCloudAPIKey: String? {
  get {
    guard let value = getenv("CACTUS_CLOUD_KEY") else { return nil }
    return String(cString: value)
  }
  set {
    if let newValue {
      setenv("CACTUS_CLOUD_KEY", newValue, 1)
    } else {
      unsetenv("CACTUS_CLOUD_KEY")
    }
  }
}
