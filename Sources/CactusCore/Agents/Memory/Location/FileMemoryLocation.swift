import Foundation

// MARK: - FileMemoryLocation

extension CactusMemoryLocation {
  public static func file<Value>(
    at url: URL,
    encoder: sending any TopLevelEncoder<Data> = JSONEncoder(),
    decoder: sending any TopLevelDecoder<Data> = JSONDecoder()
  ) -> Self where Self == FileMemoryLocation<Value> {
    FileMemoryLocation(url: url, encoder: encoder, decoder: decoder)
  }
}

public final class FileMemoryLocation<Value: Codable & Sendable>: CactusMemoryLocation {
  private let url: URL
  private let encoder: Lock<AnyTopLevelEncoder<Data>>
  private let decoder: Lock<AnyTopLevelDecoder<Data>>

  init(
    url: URL,
    encoder: sending any TopLevelEncoder<Data>,
    decoder: sending any TopLevelDecoder<Data>
  ) {
    self.url = url
    self.encoder = Lock(AnyTopLevelEncoder(encoder))
    self.decoder = Lock(AnyTopLevelDecoder(decoder))
  }

  public struct Key: Hashable, Sendable {
    let url: URL
  }

  public func key(in environment: CactusEnvironmentValues) -> Key {
    Key(url: url)
  }

  public func value(
    in environment: CactusEnvironmentValues,
    currentValue: Value
  ) async throws -> Value {
    try self.decoder.withLock { decoder in
      guard FileManager.default.fileExists(atPath: self.url.relativePath) else {
        return currentValue
      }
      return try decoder.decode(Value.self, from: Data(contentsOf: self.url))
    }
  }

  public func save(value: Value, in environment: CactusEnvironmentValues) async throws {
    let throttler = await FileThrottlerPool.shared.throttler(for: self.url)
    let data = try self.encoder.withLock { try $0.encode(value) }
    try await throttler.write(data: data)
  }
}

// MARK: - FileThrottlerPool

private final actor FileThrottlerPool {
  static let shared = FileThrottlerPool()

  private struct Entry {
    var count: Int
    let throttler: FileThrottler
  }

  private var throttlers = [URL: Entry]()

  func throttler(for url: URL) -> FileThrottler {
    if self.throttlers[url] != nil {
      self.throttlers[url]?.count += 1
      return self.throttlers[url]!.throttler
    }
    let throttler = FileThrottler(url: url)
    self.throttlers[url] = Entry(count: 1, throttler: throttler)
    return throttler
  }

  func release(for url: URL) {
    self.throttlers[url]?.count -= 1
    if self.throttlers[url]?.count == 0 {
      self.throttlers[url] = nil
    }
  }
}

// MARK: - FileThrottler

private final actor FileThrottler {
  private let url: URL
  private var throttledData: (Data, shouldCreate: Bool)?
  private var task: Task<Void, any Error>?
  private var waiter: UnsafeContinuation<Void, any Error>?

  private var fileExists: Bool {
    FileManager.default.fileExists(atPath: self.url.relativePath)
  }

  init(url: URL) {
    self.url = url
  }

  func write(data: Data) async throws {
    if self.task == nil {
      try self.ensureFileDirectory()
      try data.write(to: self.url)
      self.task = Task {
        try await self.throttle()
        self.task = nil
      }
    } else {
      self.throttledData = (data, shouldCreate: !self.fileExists)
      self.waiter?.resume()
      self.waiter = nil
      try await withUnsafeThrowingContinuation { self.waiter = $0 }
    }
  }

  private func throttle() async throws {
    defer { self.waiter = nil }
    do {
      try await Task.sleep(nanoseconds: _defaultFileMemoryLocationThrottleNanos)
      guard let (data, shouldCreate) = self.throttledData else { return }
      if shouldCreate {
        try self.ensureFileDirectory()
        try data.write(to: self.url)
      } else if self.fileExists {
        try data.write(to: self.url)
      }
      self.waiter?.resume()
    } catch {
      self.waiter?.resume(throwing: error)
    }
  }

  private func ensureFileDirectory() throws {
    try FileManager.default.createDirectory(
      at: self.url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
  }
}

package let _defaultFileMemoryLocationThrottleNanos = UInt64(1_000_000_000)
