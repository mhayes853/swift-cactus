import Cactus
import CustomDump
import Foundation
import Testing
import XCTest

#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  import SQLite3
#endif

@Suite(.serialized)
final class `CactusTelemetry tests` {
  deinit {
    CactusTelemetry.reset()
  }

  @Test
  func `Reports Issue When Registering Device Without Configuring`() {
    withKnownIssue { CactusTelemetry.registerDevice(.mock()) }
  }

  @Test
  func `Does Not Register Device When Id Available`() async throws {
    struct Client: CactusTelemetry.Client {
      let onRegister: @Sendable () -> Void

      func deviceId() async throws -> CactusTelemetry.DeviceID? {
        "blob"
      }

      func registerDevice(
        _ metadata: CactusTelemetry.DeviceMetadata
      ) async throws -> CactusTelemetry.DeviceID {
        self.onRegister()
        return "blob"
      }

      func send(
        event: any CactusTelemetry.Event & Sendable,
        with data: CactusTelemetry.ClientEventData
      ) async throws {
      }
    }

    let registerCount = Lock(0)
    let client = Client { registerCount.withLock { $0 += 1 } }
    CactusTelemetry.configure(testTelemetryToken, deviceMetadata: .mock(), client: client)
    try await Task.sleep(for: .seconds(1))

    registerCount.withLock { expectNoDifference($0, 0) }
  }
}

#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  final class CactusDefaultTelemetryTests: XCTestCase {
    override func setUp() async throws {
      try await super.setUp()
      try cleanupCactusUtilsDatabase()
    }

    override func tearDown() {
      super.tearDown()
      CactusTelemetry.reset()
    }

    func testRegistersDeviceWithClientWhenConfigured() async throws {
      let registersDevice = self.expectation(description: "registers")

      let device = CactusTelemetry.DeviceMetadata.mock()

      let client = DefaultWrapperTelemetryClient { id in
        let realId = try await defaultClient.deviceId()
        expectNoDifference(realId, id)
        registersDevice.fulfill()
      } onEventSent: { _ in
      }

      CactusTelemetry.configure(testTelemetryToken, deviceMetadata: device, client: client)
      await self.fulfillment(of: [registersDevice], timeout: 10)
    }

    func testCanSendEventsAfterRegisteringDevice() async throws {
      let registersDevice = self.expectation(description: "registers")
      let sendsEvent = self.expectation(description: "sends")

      let client = DefaultWrapperTelemetryClient { _ in
        registersDevice.fulfill()
      } onEventSent: { e in
        expectNoDifference(testEvent.name, e.name)
        sendsEvent.fulfill()
      }

      CactusTelemetry.configure(testTelemetryToken, deviceMetadata: .mock(), client: client)
      await self.fulfillment(of: [registersDevice], timeout: 10)

      CactusTelemetry.send(testEvent)
      await self.fulfillment(of: [sendsEvent], timeout: 10)
    }
  }

  private struct DefaultWrapperTelemetryClient: CactusTelemetry.Client, Sendable {
    let onDeviceRegistered: @Sendable (CactusTelemetry.DeviceID) async throws -> Void
    let onEventSent: @Sendable (sending any CactusTelemetry.Event) async throws -> Void

    func deviceId() async throws -> CactusTelemetry.DeviceID? {
      try await defaultClient.deviceId()
    }

    func registerDevice(
      _ metadata: CactusTelemetry.DeviceMetadata
    ) async throws -> CactusTelemetry.DeviceID {
      let id = try await defaultClient.registerDevice(metadata)
      try await self.onDeviceRegistered(id)
      return id
    }

    func send(
      event: any CactusTelemetry.Event & Sendable,
      with data: CactusTelemetry.ClientEventData
    ) async throws {
      try await defaultClient.send(event: event, with: data)
      try await self.onEventSent(event)
    }
  }

  private var defaultClient: any CactusTelemetry.Client & Sendable {
    .default
  }

  private func cleanupCactusUtilsDatabase() throws {
    #if os(macOS)
      let url = URL(fileURLWithPath: "~/.cactus.db")
    #else
      let documentsDirectory =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let url = documentsDirectory.appendingPathComponent("cactus.db")
    #endif

    var handle: OpaquePointer?
    _ = sqlite3_open_v2(url.relativePath, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
    sqlite3_exec(handle, "DELETE FROM app_registrations;", nil, nil, nil)
  }
#endif

extension CactusTelemetry.DeviceMetadata {
  fileprivate static func mock() -> Self {
    Self(model: "mac", os: "macOS", osVersion: "26.1", deviceId: UUID().uuidString, brand: "Apple")
  }
}

private let testEvent = CactusTelemetry.LanguageModelInitEvent(
  configuration: CactusLanguageModel.Configuration(
    modelURL: temporaryModelDirectory().appendingPathComponent(CactusLanguageModel.testModelSlug)
  )
)
