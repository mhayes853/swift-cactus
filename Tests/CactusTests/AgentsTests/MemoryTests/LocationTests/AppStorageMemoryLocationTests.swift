import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `AppStorageMemoryLocation tests` {
  private let store = UserDefaults(suiteName: "\(UUID())")!

  @Test
  func `Uses Default Value When Not Set`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.appStorage("count")) var count = 1

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
        Run { _ in self.count }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, 1)
    expectNoDifference(self.store.integer(forKey: "count"), 1)
  }

  @Test
  func `Loads Value From Store`() async throws {
    self.store.set(42, forKey: "count")

    struct MyAgent: CactusAgent {
      @Memory(.appStorage("count")) var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Int> {
        Run { _ in self.count }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, 42)
  }

  @Test
  func `Saves Value To Store`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.appStorage("count")) var count = 0

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Int, Int> {
        Run { input in
          self.count = input
          return self.count
        }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(to: 99, in: environment)

    expectNoDifference(resp.output, 99)

    await Task.megaYield()

    expectNoDifference(self.store.integer(forKey: "count"), 99)
  }

  @Test
  func `Removes Value When Setting Nil`() async throws {
    self.store.set("blob", forKey: "name")

    struct MyAgent: CactusAgent {
      @Memory(.appStorage("name")) var name: String? = nil

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, String?> {
        Run { _ in
          self.name = nil
          return self.name
        }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, nil)

    await Task.megaYield()

    expectNoDifference(self.store.string(forKey: "name"), nil)
  }

  @Test
  func `Supports RawRepresentable Values`() async throws {
    self.store.set(AccessLevel.admin.rawValue, forKey: "access")

    struct MyAgent: CactusAgent {
      @Memory(.appStorage("access")) var access: AccessLevel = .guest

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, AccessLevel> {
        Run { _ in self.access }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, .admin)
  }

  @Test
  func `Supports URL Values`() async throws {
    self.store.set(URL.swiftCactusTestsDirectory, forKey: "url")

    struct MyAgent: CactusAgent {
      @Memory(.appStorage("url")) var url = URL.testAudio

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, URL> {
        Run { _ in self.url }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, .swiftCactusTestsDirectory)
  }

  @Test
  func `Encodes And Decodes Codable Values`() async throws {
    let stored = UserSettings(id: UUID(), name: "Blob", count: 4)
    let storedData = try JSONEncoder().encode(stored)
    self.store.set(storedData, forKey: "settings")

    struct MyAgent: CactusAgent {
      @Memory(.appStorage("settings")) var settings = UserSettings(
        id: UUID(),
        name: "Default",
        count: 0
      )

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Int, UserSettings> {
        Run { input in
          self.settings.count = input
          return self.settings
        }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(to: 9, in: environment)

    expectNoDifference(resp.output.name, stored.name)

    await Task.megaYield()

    let decoded = try JSONDecoder()
      .decode(
        UserSettings.self,
        from: self.store.data(forKey: "settings") ?? Data()
      )
    expectNoDifference(decoded.count, 9)
  }

  @Test
  func `Uses Environment Default Store`() async throws {
    struct MyAgent: CactusAgent {
      @Memory(.appStorage("flag")) var flag = false

      func body(environment: CactusEnvironmentValues) -> some CactusAgent<Void, Bool> {
        Run { _ in
          self.flag.toggle()
          return self.flag
        }
      }
    }

    var environment = CactusEnvironmentValues()
    environment.defaultAppStorage = self.store

    let session = CactusAgenticSession(MyAgent())
    let resp = try await session.respond(in: environment)

    expectNoDifference(resp.output, true)
    expectNoDifference(self.store.bool(forKey: "flag"), true)
  }
}

private enum AccessLevel: Int, Sendable {
  case guest
  case admin
}

private struct UserSettings: Codable, Equatable, Sendable {
  var id: UUID
  var name: String
  var count: Int
}
