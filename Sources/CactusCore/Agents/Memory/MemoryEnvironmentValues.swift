// MARK: - Memory Store

extension CactusEnvironmentValues {
  public var sharedMemory: CactusMemoryStore {
    get { self[MemoryStoreKey.self] }
    set { self[MemoryStoreKey.self] = newValue }
  }

  private enum MemoryStoreKey: Key {
    static var defaultValue: CactusMemoryStore {
      .shared
    }
  }
}

// MARK: - Load Reason

public struct CactusMemoryLoadReason: Hashable, Sendable {
  private let rawValue: String

  public static let hydration = Self(rawValue: "hydration")
  public static let refresh = Self(rawValue: "refresh")
}

extension CactusEnvironmentValues {
  public var memoryLoadReason: CactusMemoryLoadReason {
    get { self[MemoryLoadReasonKey.self] }
    set { self[MemoryLoadReasonKey.self] = newValue }
  }

  private enum MemoryLoadReasonKey: Key {
    static var defaultValue: CactusMemoryLoadReason {
      .hydration
    }
  }
}

// MARK: - CactusMemoryScope

public struct CactusMemoryScope: Hashable, Sendable {
  public static let shared = Self(keyPath: \.sharedMemory)
  public static let session = Self(keyPath: \.sessionMemory)

  private let keyPath: KeyPath<CactusEnvironmentValues, CactusMemoryStore> & Sendable

  public init(keyPath: any KeyPath<CactusEnvironmentValues, CactusMemoryStore> & Sendable) {
    self.keyPath = keyPath
  }

  public func memory(in environment: CactusEnvironmentValues) -> CactusMemoryStore {
    environment[keyPath: self.keyPath]
  }
}

extension CactusEnvironmentValues {
  public var defaultMemoryScope: CactusMemoryScope {
    get { self[MemoryScopeKey.self] }
    set { self[MemoryScopeKey.self] = newValue }
  }

  private enum MemoryScopeKey: Key {
    static let defaultValue = CactusMemoryScope.shared
  }
}
