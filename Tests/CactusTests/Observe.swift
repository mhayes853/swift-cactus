#if canImport(Observation)
  import Observation
  import Cactus

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  func observe(_ apply: @escaping @Sendable () -> Void) -> ObserveToken {
    let token = ObserveToken()
    onChange(
      { [weak token] in
        guard let token, !token.isCancelled else { return }
        apply()
      }
    )
    return token
  }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  private func onChange(_ apply: @escaping @Sendable () -> Void) {
    withObservationTracking {
      apply()
    } onChange: {
      Task { onChange(apply) }
    }
  }

  final class ObserveToken: Sendable {
    fileprivate let _isCancelled = Lock(false)
    let onCancel: @Sendable () -> Void

    var isCancelled: Bool {
      self._isCancelled.withLock { $0 }
    }

    init(onCancel: @escaping @Sendable () -> Void = {}) {
      self.onCancel = onCancel
    }

    deinit {
      cancel()
    }

    func cancel() {
      _isCancelled.withLock { isCancelled in
        guard !isCancelled else { return }
        defer { isCancelled = true }
        onCancel()
      }
    }
  }
#endif
