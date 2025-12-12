final class LockedBox<T>: Sendable {
  let inner: Lock<T>

  init(_ value: sending T) {
    self.inner = Lock(value)
  }
}
