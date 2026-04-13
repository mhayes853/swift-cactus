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

    func testDiarizeFromAVAudioPCMBuffer() async throws {
      let request = CactusModel.PlatformDownloadRequest.pyannoteSegmentation()
      let modelURL = try await CactusModel.testModelURL(request: request)
      let model = try CactusModel(from: modelURL)

      let buffer = try testAudioPCMBuffer()

      let result = try model.diarize(buffer: buffer, maxBufferSize: 1 << 20)

      withExpectedIssue {
        assertSnapshot(of: result, as: .dump, record: true)
      }
    }

    func testSpeakerEmbeddingsFromAVAudioPCMBuffer() async throws {
      let request = CactusModel.PlatformDownloadRequest.wespeakerResnet34()
      let modelURL = try await CactusModel.testModelURL(request: request)
      let model = try CactusModel(from: modelURL)

      let buffer = try testAudioPCMBuffer()

      let embeddings = try model.speakerEmbeddings(buffer: buffer)

      withExpectedIssue {
        assertSnapshot(of: embeddings, as: .json, record: true)
      }
    }

    func testCompleteWithAVAudioPCMBuffer() async throws {
      struct Completion: Codable {
        let slug: String
        let completion: CactusModel.Completion
        let messages: [CactusModel.Message]
      }

      let request = CactusModel.PlatformDownloadRequest.gemma4_E2BIt()
      let modelURL = try await CactusModel.testModelURL(request: request)
      let model = try CactusModel(from: modelURL)

      let buffer = try testAudioPCMBuffer()

      let completed = try model.complete(
        messages: [
          .system("You are a helpful assistant."),
          .user("What is going on in the audio?")
        ],
        buffer: buffer,
        options: CactusModel.Completion.Options(maxTokens: 256)
      )

      withExpectedIssue {
        assertSnapshot(
          of: Completion(
            slug: request.slug,
            completion: completed.completion,
            messages: completed.messages
          ),
          as: .json,
          record: true
        )
      }
    }
  }

  private let audioPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
#endif
