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

      let buffer = try testAudioPCMBuffer()

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
