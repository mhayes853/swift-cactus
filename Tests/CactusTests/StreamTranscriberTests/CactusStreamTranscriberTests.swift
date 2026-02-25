import CXXCactusShims
import Cactus
import CustomDump
import Foundation
import IssueReporting
import SnapshotTesting
import Testing

#if canImport(AVFoundation)
  import AVFoundation
#endif

@Suite
struct `CactusStreamTranscriber tests` {
  @Test
  func `Throws Error When Model URL Missing`() throws {
    let missingURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("missing-model-\(UUID())")

    #expect(throws: CactusStreamTranscriberError.self) {
      _ = try CactusStreamTranscriber(modelURL: missingURL)
    }
  }

  #if canImport(AVFoundation)
    @Test
    func `Process Snapshot From Audio Slice`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .whisperSmall())
      let transcriber = try CactusStreamTranscriber(modelURL: modelURL)

      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 4)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))

      let response = try transcriber.process(buffer: slice)

      withKnownIssue {
        assertSnapshot(of: response, as: .json, record: true)
      }
    }

    @Test
    func `Finalize Snapshot After Chunked Inserts`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .whisperSmall())
      var transcriber = try CactusStreamTranscriber(modelURL: modelURL)

      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let chunkSize = max(AVAudioFramePosition(1), totalFrames / 3)

      for index in 0..<3 {
        let startFrame = AVAudioFramePosition(index) * chunkSize
        let endFrame = index == 2 ? totalFrames : startFrame + chunkSize
        let frameLength = AVAudioFrameCount(endFrame - startFrame)
        let chunk = try testAudioPCMBuffer(
          startFrame: startFrame,
          frameLength: frameLength
        )

        _ = try transcriber.process(buffer: chunk)
      }

      let response = try transcriber.stop()

      withKnownIssue {
        assertSnapshot(of: response, as: .json, record: true)
      }
    }

    @Test
    func `Disallow Operations After Finalize`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .whisperSmall())
      var transcriber = try CactusStreamTranscriber(modelURL: modelURL)

      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 4)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))

      _ = try transcriber.process(buffer: slice)
      _ = try transcriber.stop()

      #expect(throws: CactusStreamTranscriberError.self) {
        try transcriber.process(buffer: slice)
      }
      #expect(throws: CactusStreamTranscriberError.self) {
        _ = try transcriber.stop()
      }
    }

    @Test
    func `Stop Is Idempotent Through Deinit Cleanup`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .whisperSmall())
      var transcriber = try CactusStreamTranscriber(modelURL: modelURL)

      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 8)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))
      _ = try transcriber.process(buffer: slice)
      _ = try transcriber.stop()
    }
  #endif
}
