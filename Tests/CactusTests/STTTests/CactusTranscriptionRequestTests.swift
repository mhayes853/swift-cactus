import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusTranscriptionRequest tests` {
  @Test
  func `Audio Content`() {
    let content = CactusTranscription.Request.Content.audio(testAudioURL)
    expectNoDifference(content.audioURL, testAudioURL)
    expectNoDifference(content.pcmBytes, nil)
  }

  @Test
  func `PCM Content`() {
    let content = CactusTranscription.Request.Content.pcm([1, 2, 3])
    expectNoDifference(content.audioURL, nil)
    expectNoDifference(content.pcmBytes, [1, 2, 3])
  }

  @Test
  func `useVad defaults to true when timestamps included`() {
    let request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    expectNoDifference(request.useVad, true)
  }

  @Test
  func `useVad defaults to nil when timestamps excluded`() {
    let request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL)
    )
    expectNoDifference(request.useVad, nil)
  }

  @Test
  func `useVad respects explicit false when timestamps included`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    request.useVad = false
    expectNoDifference(request.useVad, false)
  }

  @Test
  func `prompt includeTimestamps modification triggers useVad when nil`() throws {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL)
    )
    expectNoDifference(request.useVad, nil)
    guard case .whisper(var whisper) = request.prompt else {
      throw TestError("Expected whisper case")
    }
    whisper.includeTimestamps = true
    request.prompt = .whisper(whisper)
    expectNoDifference(request.useVad, true)
  }

  @Test
  func `prompt includeTimestamps modification preserves explicit false useVad`() throws {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL),
      useVad: false
    )
    expectNoDifference(request.useVad, false)
    guard case .whisper(var whisper) = request.prompt else {
      throw TestError("Expected whisper case")
    }
    whisper.includeTimestamps = true
    request.prompt = .whisper(whisper)
    expectNoDifference(request.useVad, false)
  }

  @Test
  func `prompt language modification updates prompt description`() throws {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    guard case .whisper(var whisper) = request.prompt else {
      throw TestError("Expected whisper case")
    }
    whisper.language = .french
    request.prompt = .whisper(whisper)
    expectNoDifference(request.prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
  }
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!

private enum TestError: Error {
  case message(String)
  
  init(_ message: String) {
    self = .message(message)
  }
}
