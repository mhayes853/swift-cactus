import Cactus
import CustomDump
import Foundation
import Testing

@Suite
final class `FileMemoryLocation tests` {
  private let url = temporaryModelDirectory().appending(path: "\(UUID()).json")

  init() throws {
    try FileManager.default.createDirectory(
      at: self.url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

  @Test
  func `Uses Default Value When File Not Found`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: String

      init(url: URL) {
        self._file = Memory(wrappedValue: "", .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, String> {
        Run { _ in self.file }
      }
    }

    let session = CactusAgenticSession(MyAgent(url: self.url))
    let resp = try await session.respond()

    expectNoDifference(resp.output, "")
  }

  @Test
  func `Decodes Value From File`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: MyCodable

      init(url: URL) {
        self._file = Memory(wrappedValue: MyCodable(a: "a", b: 1), .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, MyCodable> {
        Run { _ in self.file }
      }
    }

    let value = MyCodable(a: "blob", b: 4000)
    try JSONEncoder().encode(value).write(to: self.url)

    let session = CactusAgenticSession(MyAgent(url: self.url))
    let resp = try await session.respond()

    expectNoDifference(resp.output, value)
  }

  @Test
  func `Encodes Value To File`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: MyCodable

      init(url: URL) {
        self._file = Memory(wrappedValue: MyCodable(a: "a", b: 1), .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<MyCodable, MyCodable> {
        Run { input in
          self.file = input
          return self.file
        }
      }
    }

    let value = MyCodable(a: "blob", b: 4000)
    let session = CactusAgenticSession(MyAgent(url: self.url))
    let resp = try await session.respond(to: value)

    expectNoDifference(resp.output, value)

    await Task.megaYield()

    let decoded = try JSONDecoder().decode(MyCodable.self, from: Data(contentsOf: self.url))
    expectNoDifference(decoded, value)
  }

  @Test
  func `Throttles Encodes To File`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: MyCodable

      init(url: URL) {
        self._file = Memory(wrappedValue: MyCodable(a: "a", b: 1), .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<MyCodable, MyCodable> {
        Run { input in
          self.file = .intermediate
          await Task.megaYield()
          self.file = input
          return self.file
        }
      }
    }

    var value = MyCodable.intermediate
    value.b += 1

    let session = CactusAgenticSession(MyAgent(url: self.url))
    let resp = try await session.respond(to: value)

    expectNoDifference(resp.output, value)

    var decoded = try JSONDecoder().decode(MyCodable.self, from: Data(contentsOf: self.url))
    expectNoDifference(decoded, .intermediate)

    try await Task.sleep(nanoseconds: sleepTime)

    decoded = try JSONDecoder().decode(MyCodable.self, from: Data(contentsOf: self.url))
    expectNoDifference(decoded, value)
  }

  @Test
  func `Drops Write When File Removed During Throttle`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: MyCodable

      init(url: URL) {
        self._file = Memory(wrappedValue: MyCodable(a: "a", b: 1), .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<MyCodable, MyCodable> {
        Run { input in
          self.file = .intermediate
          await Task.megaYield()
          self.file = input
          return self.file
        }
      }
    }

    var value = MyCodable.intermediate
    value.b += 1

    let session = CactusAgenticSession(MyAgent(url: self.url))
    _ = try await session.respond(to: value)

    await Task.megaYield()

    try FileManager.default.removeItem(at: self.url)

    try await Task.sleep(nanoseconds: sleepTime)

    expectNoDifference(FileManager.default.fileExists(atPath: self.url.relativePath), false)
  }

  @Test
  func `Writes When File Non-Existent Before Throttle`() async throws {
    struct MyAgent: CactusAgent {
      @Memory var file: MyCodable
      private let url: URL

      init(url: URL) {
        self.url = url
        self._file = Memory(wrappedValue: MyCodable(a: "a", b: 1), .file(at: url))
      }

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<MyCodable, MyCodable> {
        Run { input in
          self.file = .intermediate
          await Task.megaYield()
          self.file = .blank
          await Task.megaYield()
          try FileManager.default.removeItem(at: self.url)
          self.file = input
          return self.file
        }
      }
    }

    var value = MyCodable.intermediate
    value.b += 1

    let session = CactusAgenticSession(MyAgent(url: self.url))
    _ = try await session.respond(to: value)
    try await Task.sleep(nanoseconds: sleepTime)

    let decoded = try JSONDecoder().decode(MyCodable.self, from: Data(contentsOf: self.url))
    expectNoDifference(decoded, value)
  }
}

private struct MyCodable: Hashable, Codable, Sendable {
  static let intermediate = Self(a: "blob", b: 4000)
  static let blank = Self(a: "", b: 0)

  var a: String
  var b: Int
}

private let sleepTime = _defaultFileMemoryLocationThrottleNanos + 100_000_000
