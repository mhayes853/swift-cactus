// MARK: - CactusSubscription

/// A type that the library uses for managing subscriptions to data sources.
///
/// You can create a subscription with a closure that runs when ``cancel()`` is called.
///
/// ```swift
/// let subscription = CactusSubscription {
///   print("Cancelled, performing cleanup work!")
/// }
/// ```
///
/// The above closure is guaranteed to be invoked at most a single time, so you do not need to
/// consider the case where cancellation is invoked more than once.
///
/// A subscription is automatically cancelled when deallocated. Therefore, make sure you hold a
/// strong reference to a subscription for the duration of its usage.
public struct CactusSubscription: Sendable {
  private let box: Box

  /// Creates a subscription with a closure that runs when the subscription is cancelled.
  ///
  /// The specified closure will only be ran 1 time at most.
  ///
  /// - Parameter onCancel: A closure that runs when ``cancel()`` is invoked.
  public init(onCancel: @Sendable @escaping () -> Void) {
    self.box = Box(onCancel: onCancel)
  }

  /// Cancels this subscription.
  ///
  /// Invoking this method multiple times will have no effect after the first invocation.
  public func cancel() {
    self.box.cancel()
  }
}

// MARK: - Equatable

extension CactusSubscription: Equatable {
  public static func == (lhs: CactusSubscription, rhs: CactusSubscription) -> Bool {
    lhs.box === rhs.box
  }
}

// MARK: - Hashable

extension CactusSubscription: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self.box))
  }
}

// MARK: - Box

extension CactusSubscription {
  private final class Box: Sendable {
    private let onCancel: Lock<(@Sendable () -> Void)?>

    init(onCancel: @escaping @Sendable () -> Void) {
      self.onCancel = Lock(onCancel)
    }

    deinit { self.cancel() }

    func cancel() {
      self.onCancel.withLock { cancel in
        defer { cancel = nil }
        cancel?()
      }
    }
  }
}
