import Cactus
import CustomDump
import Foundation
import IssueReporting
import SnapshotTesting
import Testing

@Suite
struct `CactusVADSession tests` {
  @Test
  func `File VAD Snapshot`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .sileroVad())
    let session = try CactusVADSession(from: modelURL)
    let request = CactusVAD.Request(content: .audio(testAudioURL))

    let vad = try await session.vad(request: request)

    withKnownIssue {
      assertSnapshot(of: vad, as: .dump, record: true)
    }
  }

  @Test
  func `Canceling VAD Throws Immediate Cancellation Error`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .sileroVad())
    let session = try CactusVADSession(from: modelURL)
    let request = CactusVAD.Request(content: .pcm(longSilencePCMBytes))

    let task = Task {
      try await session.vad(request: request)
    }

    try await Task.sleep(for: .milliseconds(50))
    task.cancel()

    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }

  @Test
  func `Canceling VAD Immediately Throws Cancellation Error`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .sileroVad())
    let session = try CactusVADSession(from: modelURL)
    let request = CactusVAD.Request(content: .pcm(longSilencePCMBytes))

    let task = Task {
      try await session.vad(request: request)
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }

  @Test
  func `VAD With Custom Executor Succeeds`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .sileroVad())
    let model = try CactusModelActor(
      executor: DispatchQueueSerialExecutor(),
      from: modelURL
    )
    let session = CactusVADSession(model: model)
    let request = CactusVAD.Request(content: .audio(testAudioURL))

    let vad = try await session.vad(request: request)

    expectNoDifference(vad.segments.isEmpty, false)
  }

  #if canImport(AVFoundation)
    @Test
    func `PCM Buffer VAD Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .sileroVad())
      let session = try CactusVADSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusVAD.Request.Content.pcm(pcmBuffer)
      let request = CactusVAD.Request(content: content)

      let vad = try await session.vad(request: request)

      withKnownIssue {
        assertSnapshot(of: vad, as: .dump, record: true)
      }
    }
  #endif
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
private let longSilencePCMBytes = [UInt8](repeating: 0, count: 3_200_000)
