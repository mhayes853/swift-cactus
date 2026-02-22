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
  func `prompt includeTimestamps modification triggers useVad when nil`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL)
    )
    expectNoDifference(request.useVad, nil)
    request.prompt.includeTimestamps = true
    expectNoDifference(request.useVad, true)
  }

  @Test
  func `prompt includeTimestamps modification preserves explicit false useVad`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL),
      useVad: false
    )
    expectNoDifference(request.useVad, false)
    request.prompt.includeTimestamps = true
    expectNoDifference(request.useVad, false)
  }

  @Test
  func `prompt language modification updates prompt description`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    request.prompt.language = .french
    expectNoDifference(request.prompt.language, .french)
    expectNoDifference(request.prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
  }
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
