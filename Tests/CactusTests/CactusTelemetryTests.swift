import Cactus
import CustomDump
import Foundation
import XCTest

final class CactusTelemetryTests: XCTestCase {
  override func setUp() async throws {
    try await super.setUp()

    let documentsDirectory =
      FileManager.default
      .urls(
        for: .documentDirectory,
        in: .userDomainMask
      )[0]
    try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent("cactus.db"))
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

      let event = CactusTelemetry.Event(name: "blob")

      let client = DefaultWrapperTelemetryClient { _ in
        registersDevice.fulfill()
      } onEventSent: { e in
        expectNoDifference(event.name, e.name)
        sendsEvent.fulfill()
      }

      CactusTelemetry.configure(testTelemetryToken, deviceMetadata: .mock(), client: client)
      await self.fulfillment(of: [registersDevice], timeout: 10)

      CactusTelemetry.send(event: event)
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
        event: CactusTelemetry.Event,
        token: String,
        deviceId: CactusTelemetry.DeviceID
      ) async throws {
      }
    }

    let registersDevice = self.expectation(description: "registers")
    registersDevice.isInverted = true
    let client = Client(registersDevice: registersDevice)

    CactusTelemetry.configure(testTelemetryToken, deviceMetadata: .mock(), client: client)
    await self.fulfillment(of: [registersDevice], timeout: 1)
  }
}

#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  private struct DefaultWrapperTelemetryClient: CactusTelemetry.Client, Sendable {
    let onDeviceRegistered: @Sendable (CactusTelemetry.DeviceID) async throws -> Void
    let onEventSent: @Sendable (CactusTelemetry.Event) async throws -> Void

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
      event: CactusTelemetry.Event,
      token: String,
      deviceId: CactusTelemetry.DeviceID
    ) async throws {
      try await CactusTelemetry.defaultClient.send(event: event, token: token, deviceId: deviceId)
      try await self.onEventSent(event)
    }
  }
#endif

extension CactusTelemetry.DeviceMetadata {
  fileprivate static func mock() -> Self {
    Self(model: "mac", os: "macOS", osVersion: "26.1", deviceId: UUID().uuidString, brand: "Apple")
  }
}
