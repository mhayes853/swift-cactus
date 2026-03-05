#if canImport(AVFoundation)
  import AVFoundation
  import Cactus
  import CustomDump
  import Foundation
  import IssueReporting
  import SnapshotTesting
  import XCTest

  final class CactusModelAVFoundationTests: XCTestCase {
    func testTranscribesAVAudioPCMBuffer() async throws {
      struct Transcription: Codable {
        let slug: String
        let transcription: CactusModel.Transcription
      }

      let request = CactusModel.PlatformDownloadRequest.whisperSmall()
      let modelURL = try await CactusModel.testModelURL(request: request)
      let model = try CactusModel(from: modelURL)

      let buffer = try testAudioPCMBuffer()

      let transcription = try model.transcribe(buffer: buffer, prompt: audioPrompt)

      withExpectedIssue {
        assertSnapshot(
          of: Transcription(slug: request.slug, transcription: transcription),
          as: .json,
          record: true
        )
      }
    }

    func testDetectsLanguageFromAVAudioPCMBuffer() async throws {
      let request = CactusModel.PlatformDownloadRequest.whisperSmall()
      let modelURL = try await CactusModel.testModelURL(request: request)
      let model = try CactusModel(from: modelURL)

      let buffer = try testAudioPCMBuffer()

      let detection = try model.detectLanguage(buffer: buffer)

      expectNoDifference(detection.language, "en")
      expectNoDifference((0...1).contains(detection.confidence), true)
    }
  }

  private let audioPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
#endif
