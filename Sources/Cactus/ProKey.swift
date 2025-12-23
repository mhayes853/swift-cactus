/// The pro key used to enable NPU acceleration.
///
/// You'll want to set this key when your application launches initially. The engine will
/// automatically detect the key to enable NPU acceleration.
/// ```swift
/// import Cactus
///
/// Cactus.proKey = "your_pro_key_here"
/// ```
public var proKey: String? {
  get { _proKey.withLock { $0 } }
  set { _proKey.withLock { $0 = newValue } }
}

private let _proKey = Lock<String?>(nil)
