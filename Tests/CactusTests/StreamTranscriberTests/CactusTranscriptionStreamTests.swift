import Cactus
import Foundation
import IssueReporting
import SnapshotTesting
import Testing

#if canImport(AVFoundation)
  import AVFoundation
#endif

@Suite
struct `CactusTranscriptionStream tests` {
  #if canImport(AVFoundation)
    @Test
    func `Async Sequence Snapshot From Stream Inserts`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let stream = try CactusTranscriptionStream(modelURL: modelURL, contextSize: 2048)

      let recordingTask = Task {
        var chunks = [CactusStreamTranscriber.ProcessedTranscription]()
        for try await chunk in stream {
          chunks.append(chunk)
        }
        return chunks
      }

      try await Task.sleep(nanoseconds: 100_000_000)

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

        try await stream.insert(buffer: chunk)
      }

      _ = try await stream.finish()

      let chunks = try await recordingTask.value

      withExpectedIssue {
        assertSnapshot(of: chunks, as: .json, record: true)
      }
    }
  #endif
}
