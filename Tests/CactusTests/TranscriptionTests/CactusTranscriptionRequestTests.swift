import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusTranscriptionRequest tests` {
  @Test
  func `Prompt With Timestamps`() {
    let request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    expectNoDifference(request.prompt, "<|startoftranscript|><|en|><|transcribe|>")
  }

  @Test
  func `Prompt Without Timestamps`() {
    let request = CactusTranscription.Request(
      language: .french,
      includeTimestamps: false,
      content: .audio(testAudioURL)
    )
    expectNoDifference(
      request.prompt,
      "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>"
    )
  }

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
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
