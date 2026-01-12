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
      try CactusStreamTranscriber(modelURL: missingURL, contextSize: 2048)
    }
  }

  @Test
  func `Stream Transcriber Does Not Deallocate Model Pointer`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")
    let modelPointer = try #require(cactus_init(modelURL.nativePath, 2048, nil))
    defer { cactus_destroy(modelPointer) }

    do {
      _ = try CactusStreamTranscriber(model: modelPointer, isModelPointerManaged: false)
    }

    let model = try CactusLanguageModel(
      model: modelPointer,
      configuration: CactusLanguageModel.Configuration(modelURL: modelURL)
    )
    #expect(throws: Never.self) {
      try model.audioEmbeddings(
        for: Bundle.module.url(forResource: "test", withExtension: "wav")!
      )
    }
  }

  #if canImport(AVFoundation)
    @Test
    func `Process Snapshot From Audio Slice`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")
      let transcriber = try CactusStreamTranscriber(modelURL: modelURL, contextSize: 2048)

      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 4)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))

      try transcriber.insert(buffer: slice)
      let response = try transcriber.process()

      withExpectedIssue {
        assertSnapshot(of: response, as: .json, record: true)
      }
    }

    @Test
    func `Finalize Snapshot After Chunked Inserts`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")
      let transcriber = try CactusStreamTranscriber(modelURL: modelURL, contextSize: 2048)

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

        try transcriber.insert(buffer: chunk)
        _ = try transcriber.process()
      }

      let response = try transcriber.finalize()

      withExpectedIssue {
        assertSnapshot(of: response, as: .json, record: true)
      }
    }

    @Test
    func `Stream Transcriber Pointer Is Not Deallocated When Not Managed`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")
      let modelPointer = try #require(cactus_init(modelURL.nativePath, 2048, nil))
      defer { cactus_destroy(modelPointer) }

      let streamPointer = try #require(cactus_stream_transcribe_init(modelPointer))
      defer { cactus_stream_transcribe_destroy(streamPointer) }

      do {
        _ = CactusStreamTranscriber(streamTranscribe: streamPointer)
      }

      let restored = CactusStreamTranscriber(streamTranscribe: streamPointer)
      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 8)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))
      #expect(throws: Never.self) {
        try restored.insert(buffer: slice)
      }
    }
  #endif
}
