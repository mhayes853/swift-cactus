import Foundation

// MARK: - Lock

package struct Lock<Value: ~Copyable>: ~Copyable {
  private let lock = NSLock()
  private var value: UnsafeMutablePointer<Value>

  package init(_ value: consuming sending Value) {
    self.value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
    self.value.initialize(to: value)
  }

  deinit { self.value.deallocate() }

  package borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try body(&self.value.pointee)
  }
}

extension Lock: @unchecked Sendable where Value: ~Copyable {}

// MARK: - RecursiveLock

package struct RecursiveLock<Value: ~Copyable>: ~Copyable {
  private let lock = NSRecursiveLock()
  private var value: UnsafeMutablePointer<Value>

  /// Creates a lock by consuming the specified value.
  ///
  /// - Parameter value: The initial value of the lock.
  package init(_ value: consuming sending Value) {
    self.value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
    self.value.initialize(to: value)
  }

  deinit { self.value.deallocate() }

  /// Calls the specified closure with the lock acquired and gives up ownership of the value.
  ///
  /// - Parameter body: A closure with mutable access to the underlying value.
  /// - Returns: Whatever `body` returns.
  package borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try body(&self.value.pointee)
  }
}

extension RecursiveLock: @unchecked Sendable where Value: ~Copyable {}
