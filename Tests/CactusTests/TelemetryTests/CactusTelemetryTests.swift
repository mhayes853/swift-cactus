import Cactus
import CustomDump
import Foundation
import Testing
import XCTest

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
    try await Task.sleep(nanoseconds: nanosecondsPerSecond)

    registerCount.withLock { expectNoDifference($0, 0) }
  }
}

let nanosecondsPerSecond = UInt64(1_000_000_000)

#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  final class CactusDefaultTelemetryTests: XCTestCase {
    override func tearDown() {
      super.tearDown()
      CactusTelemetry.reset()
    }

    func testRegistersDeviceWithClientWhenConfigured() async throws {
      try await withBlankCactusUtilsDatabase {
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
    }

    func testCanSendEventsAfterRegisteringDevice() async throws {
      try await withBlankCactusUtilsDatabase {
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

#endif

private let testEvent = CactusTelemetry.LanguageModelInitEvent(
  configuration: CactusLanguageModel.Configuration(
    modelURL: temporaryModelDirectory().appendingPathComponent(CactusLanguageModel.testModelSlug)
  )
)
