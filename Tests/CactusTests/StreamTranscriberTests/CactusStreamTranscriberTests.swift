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
      try CactusStreamTranscriber(modelURL: missingURL)
    }
  }

  @Test
  func `Stream Transcriber Does Not Deallocate Model Pointer`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let modelPointer = try #require(cactus_init(modelURL.nativePath, nil, false))
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
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
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
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let transcriber = try CactusStreamTranscriber(modelURL: modelURL)

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
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let transcriber = try CactusStreamTranscriber(modelURL: modelURL)

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
    func `Stream Transcriber Pointer Is Not Deallocated When Not Managed`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let modelPointer = try #require(cactus_init(modelURL.nativePath, nil, false))
      defer { cactus_destroy(modelPointer) }

      let streamPointer = try #require(cactus_stream_transcribe_start(modelPointer, nil))
      defer {
        let responseBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 8192)
        defer { responseBuffer.deallocate() }
        _ = cactus_stream_transcribe_stop(streamPointer, responseBuffer, 8192)
      }

      do {
        _ = CactusStreamTranscriber(streamTranscribe: streamPointer)
      }

      let restored = CactusStreamTranscriber(streamTranscribe: streamPointer)
      let fullBuffer = try testAudioPCMBuffer()
      let totalFrames = AVAudioFramePosition(fullBuffer.frameLength)
      let sliceLength = max(AVAudioFramePosition(1), totalFrames / 8)
      let slice = try testAudioPCMBuffer(frameLength: AVAudioFrameCount(sliceLength))
      #expect(throws: Never.self) {
        try restored.process(buffer: slice)
      }
    }
  #endif
}
