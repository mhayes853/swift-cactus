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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .sileroVad())
    let session = try CactusVADSession(from: modelURL)
    let request = CactusVAD.Request(content: .audio(testAudioURL))

    let vad = try await session.vad(request: request)

    withKnownIssue {
      assertSnapshot(
        of: VADSessionSnapshot(vad: vad),
        as: .json,
        record: true
      )
    }
  }

  @Test
  func `Canceling VAD Throws Immediate Cancellation Error`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .sileroVad())
    let session = try CactusVADSession(from: modelURL)
    let request = CactusVAD.Request(content: .pcm(longSilencePCMBytes))

    let task = Task {
      try await session.vad(request: request)
    }
    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }

  #if canImport(AVFoundation)
    @Test
    func `PCM Buffer VAD Snapshot`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .sileroVad())
      let session = try CactusVADSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusVAD.Request.Content.pcm(pcmBuffer)
      let request = CactusVAD.Request(content: content)

      let vad = try await session.vad(request: request)

      withKnownIssue {
        assertSnapshot(
          of: VADSessionSnapshot(vad: vad),
          as: .json,
          record: true
        )
      }
    }
  #endif
}

private struct VADSessionSnapshot: Codable {
  let segments: [Segment]
  let ramUsageMb: Double
  let totalDuration: CactusDuration
  let samplingRate: Int

  init(vad: CactusVAD) {
    self.segments = vad.segments.map { .init(segment: $0) }
    self.ramUsageMb = vad.ramUsageMb
    self.totalDuration = vad.totalDuration
    self.samplingRate = vad.samplingRate
  }

  struct Segment: Codable {
    let startFrame: Int
    let endFrame: Int
    let startDuration: CactusDuration
    let endDuration: CactusDuration
    let duration: CactusDuration

    init(segment: CactusVAD.Segment) {
      self.startFrame = segment.startFrame
      self.endFrame = segment.endFrame
      self.startDuration = segment.startDuration
      self.endDuration = segment.endDuration
      self.duration = segment.duration
    }
  }
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
private let longSilencePCMBytes = [UInt8](repeating: 0, count: 3_200_000)
