import Cactus
import CustomDump
import Foundation
import SQLite3
import XCTest

final class CactusTelemetryTests: XCTestCase {
  override func setUp() async throws {
    try await super.setUp()
    try cleanupCactusUtilsDatabase()
  }

  override func tearDown() {
    super.tearDown()
    CactusTelemetry.reset()
  }

  func testReportsIssueWhenRegisteringDeviceWithoutConfiguring() {
    XCTExpectFailure { CactusTelemetry.registerDevice(.mock()) }
  }

  #if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
    func testRegistersDeviceWithClientWhenConfigured() async throws {
      let registersDevice = self.expectation(description: "registers")

      let device = CactusTelemetry.DeviceMetadata.mock()

      let client = DefaultWrapperTelemetryClient { id in
        let realId = try await CactusTelemetry.defaultClient.deviceId()
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

      CactusTelemetry.send(event: testEvent)
      await self.fulfillment(of: [sendsEvent], timeout: 10)
    }
  #endif

  func testDoesNotRegisterDeviceWhenIdAvailable() async throws {
    struct Client: CactusTelemetry.Client {
      let registersDevice: XCTestExpectation

      func deviceId() async throws -> CactusTelemetry.DeviceID? {
        "blob"
      }

      func registerDevice(
        _ metadata: CactusTelemetry.DeviceMetadata
      ) async throws -> CactusTelemetry.DeviceID {
        registersDevice.fulfill()
        return "blob"
      }

      func send(
        event: any CactusTelemetry.Event & Sendable,
        with data: CactusTelemetry.ClientEventData
      ) async throws {
      }
    }

    let registersDevice = self.expectation(description: "registers")
    registersDevice.isInverted = true
    let client = Client(registersDevice: registersDevice)

    CactusTelemetry.configure(testTelemetryToken, deviceMetadata: .mock(), client: client)
    await self.fulfillment(of: [registersDevice], timeout: 1)
  }

  func testProjectIdIsAUUIDV5() {
    expectNoDifference(CactusTelemetry.projectId, "bc412594-249d-5b93-968b-c6cd782afc73")
  }
}

#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  private struct DefaultWrapperTelemetryClient: CactusTelemetry.Client, Sendable {
    let onDeviceRegistered: @Sendable (CactusTelemetry.DeviceID) async throws -> Void
    let onEventSent: @Sendable (sending any CactusTelemetry.Event) async throws -> Void

    func deviceId() async throws -> CactusTelemetry.DeviceID? {
      try await CactusTelemetry.defaultClient.deviceId()
    }

    func registerDevice(
      _ metadata: CactusTelemetry.DeviceMetadata
    ) async throws -> CactusTelemetry.DeviceID {
      let id = try await CactusTelemetry.defaultClient.registerDevice(metadata)
      try await self.onDeviceRegistered(id)
      return id
    }

    func send(
      event: any CactusTelemetry.Event & Sendable,
      with data: CactusTelemetry.ClientEventData
    ) async throws {
      try await CactusTelemetry.defaultClient.send(event: event, with: data)
      try await self.onEventSent(event)
    }
  }
#endif

extension CactusTelemetry.DeviceMetadata {
  fileprivate static func mock() -> Self {
    Self(model: "mac", os: "macOS", osVersion: "26.1", deviceId: UUID().uuidString, brand: "Apple")
  }
}

private let testEvent = CactusTelemetry.LanguageModelInitEvent(
  configuration: CactusLanguageModel.Configuration(
    modelURL: temporaryDirectory().appendingPathComponent(CactusLanguageModel.testModelSlug)
  )
)

private func cleanupCactusUtilsDatabase() throws {
  #if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
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
  #endif
}
