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

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  func access<Subject: _Observable, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    #if canImport(Observation)
      (self.registrar as! ObservationRegistrar).access(subject, keyPath: keyPath)
    #endif
  }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  func withMutation<Subject: _Observable, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    #if canImport(Observation)
      return try (self.registrar as! ObservationRegistrar)
        .withMutation(of: subject, keyPath: keyPath, mutation)
    #else
      return try mutation()
    #endif
  }
}
