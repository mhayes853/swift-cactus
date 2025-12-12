// MARK: - Memory Store

extension CactusEnvironmentValues {
  public var memoryStore: CactusMemoryStore {
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
