#if canImport(AVFoundation)
  import AVFoundation
  import Cactus
  import Foundation
  import IssueReporting
  import SnapshotTesting
  import XCTest

  final class CactusLanguageModelAVFoundationTests: XCTestCase {
    func testTranscribesAVAudioPCMBuffer() async throws {
      struct Transcription: Codable {
        let slug: String
        let transcription: CactusLanguageModel.Transcription
      }

      let modelURL = try await CactusLanguageModel.testAudioModelURL(slug: "whisper-small")
      let model = try CactusLanguageModel(from: modelURL)

      let audioURL = try XCTUnwrap(Bundle.module.url(forResource: "test", withExtension: "wav"))
      let audioFile = try AVAudioFile(forReading: audioURL)
      let format = audioFile.processingFormat
      let frameCount = AVAudioFrameCount(audioFile.length)
      let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
      try audioFile.read(into: buffer)

      let transcription = try model.transcribe(buffer: buffer, prompt: audioPrompt)

      withExpectedIssue {
        assertSnapshot(
          of: Transcription(slug: model.configuration.modelSlug, transcription: transcription),
          as: .json,
          record: true
        )
      }
    }
  }

  private let audioPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
#endif
