import Cactus
import CustomDump
import Foundation
import Testing

@Suite
final class `CactusTelemetry+Batcher tests` {
  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("cactus-telemetry-\(UUID()).json")

  deinit {
    try? FileManager.default.removeItem(at: self.fileURL)
  }

  @Test
  func `Appends Failed Uploads To Batch`() async throws {
    let state = Lock((0, [CactusTelemetry.Batcher.Event]()))
    let batcher = CactusTelemetry.Batcher(fileURL: self.fileURL) { batch in
      try state.withLock { state in
        if state.0 == 0 {
          state.0 += 1
          throw SomeError()
        } else {
          state.1 = batch
        }
      }
    }

    let event1 = CactusTelemetry.Batcher.Event(eventType: "1", framework: "", frameworkVersion: "")
    let event2 = CactusTelemetry.Batcher.Event(eventType: "2", framework: "", frameworkVersion: "")

    try? await batcher.record(event: event1)
    try await batcher.record(event: event2)
    state.withLock { expectNoDifference($0.1, [event1, event2]) }
  }

  @Test
  func `Resets Batch When All Events Uploaded`() async throws {
    let state = Lock((0, [CactusTelemetry.Batcher.Event]()))
    let batcher = CactusTelemetry.Batcher(fileURL: self.fileURL) { batch in
      try state.withLock { state in
        if state.0 == 0 {
          state.0 += 1
          throw SomeError()
        } else {
          state.1 = batch
        }
      }
    }

    let event1 = CactusTelemetry.Batcher.Event(eventType: "1", framework: "", frameworkVersion: "")
    let event2 = CactusTelemetry.Batcher.Event(eventType: "2", framework: "", frameworkVersion: "")
    let event3 = CactusTelemetry.Batcher.Event(eventType: "3", framework: "", frameworkVersion: "")

    try? await batcher.record(event: event1)
    try await batcher.record(event: event2)
    try await batcher.record(event: event3)
    state.withLock { expectNoDifference($0.1, [event3]) }
  }

  @Test
  func `Serializes Batch Uploads`() async throws {
    let state = Lock((0, [Int]()))
    let batcher = CactusTelemetry.Batcher(fileURL: self.fileURL) { batch in
      try state.withLock { state in
        if state.0 == 0 {
          state.0 += 1
          throw SomeError()
        } else {
          state.1.append(batch.count)
        }
      }
    }

    let event1 = CactusTelemetry.Batcher.Event(eventType: "1", framework: "", frameworkVersion: "")
    let event2 = CactusTelemetry.Batcher.Event(eventType: "2", framework: "", frameworkVersion: "")
    let event3 = CactusTelemetry.Batcher.Event(eventType: "3", framework: "", frameworkVersion: "")

    try? await batcher.record(event: event1)
    async let upload: Void = batcher.record(event: event2)
    async let upload2: Void = batcher.record(event: event3)
    _ = try await (upload, upload2)
    state.withLock {
      expectNoDifference(
        $0.1,
        [2, 1],
        "Since the uploads are serialized, only the first recording instance should send everything in the batch."
      )
    }
  }

  private struct SomeError: Error {}
}
