// MARK: - MemoryStore

public final class MemoryStore: Sendable {
  private let values = Lock([Key: any Sendable]())

  public init() {}

  public subscript(key: Key) -> (any Sendable)? {
    get { self.values.withLock { $0[key] } }
    set { self.values.withLock { $0[key] = newValue } }
  }
}

extension MemoryStore {
  public struct Key: Hashable, Sendable {
    public var level: Int
    public var index: Int

    public init(level: Int, index: Int) {
      self.level = level
      self.index = index
    }
  }
}

// MARK: - Environment

extension CactusEnvironmentValues {
  public var memoryStore: MemoryStore {
    get { self[MemoryStoreKey.self] }
    set { self[MemoryStoreKey.self] = newValue }
  }

  private enum MemoryStoreKey: Key {
    static var defaultValue: MemoryStore {
      MemoryStore()
    }
  }
}
