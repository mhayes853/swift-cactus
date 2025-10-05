// MARK: - CactusSubscription

/// A type that the library uses for managing subscriptions to data sources.
///
/// This type is akin to `AnyCancellable` from Combine, but it provides a few optimized usage and
/// equality tools.
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
/// A subscription is automatically deallocated when cancelled. Therefore, make sure you hold a
/// strong reference to a subscription for the duration of its usage.
public struct CactusSubscription: Sendable {
  private let box: Box

  /// Creates a subscription with a closure that runs when the subscription is cancelled.
  ///
  /// The specified closure will only be ran 1 time at most.
  ///
  /// Do not use this initializer to create subscriptions that perform no work. Use ``empty``
  /// instead.
  ///
  /// Do not use this intitializer to create subscriptions that cancel a collection of
  /// subscriptions. Use ``OperationSubscription/combined(_:)-(OperationSubscription...)`` instead.
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

  /// Stores this subscription in a set of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// - Parameter set: The set to store the subscription in.
  public func store(in set: inout Set<CactusSubscription>) {
    set.insert(self)
  }

  /// Stores this subscription in a collection of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// - Parameter collection: The collection to store the subscription in.
  public func store(in collection: inout some RangeReplaceableCollection<CactusSubscription>) {
    collection.append(self)
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
