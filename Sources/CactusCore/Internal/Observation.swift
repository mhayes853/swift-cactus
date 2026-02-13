#if canImport(Observation)
  import Observation
#endif

// MARK: - _Observable

#if canImport(Observation)
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  protocol _Observable: Observable {}
#else
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  protocol _Observable {}
#endif

// MARK: - ObservationRegistrarWrapper

struct _ObservationRegistrar: Sendable {
  #if canImport(Observation)
    private let registrar: (any Sendable)?
  #endif

  init() {
    #if canImport(Observation)
      if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
        self.registrar = ObservationRegistrar()
      } else {
        self.registrar = nil
      }
    #endif
  }

  func access<Subject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    #if canImport(Observation)
      guard #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) else { return }
      func open<S: _Observable>(_ s: S) {
        (self.registrar as! ObservationRegistrar)
          .access(s, keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self))
      }
      guard let subject = subject as? any _Observable else { return }
      open(subject)
    #endif
  }

  func withMutation<Subject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    #if canImport(Observation)
      guard #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) else {
        return try mutation()
      }
      func open<S: _Observable>(_ s: S, _ mutation: () throws -> T) rethrows -> T {
        try (self.registrar as! ObservationRegistrar)
          .withMutation(
            of: s,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self),
            mutation
          )
      }
      guard let subject = subject as? any _Observable else { return try mutation() }
      return try open(subject, mutation)
    #else
      return try mutation()
    #endif
  }
}
