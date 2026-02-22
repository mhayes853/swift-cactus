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
  func `includeTimestamps true to true is no-op`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    let originalPrompt = request.prompt
    request.includeTimestamps = true
    expectNoDifference(request.prompt, originalPrompt)
    expectNoDifference(request.includeTimestamps, true)
  }

  @Test
  func `includeTimestamps true to false removes timestamps`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    request.includeTimestamps = false
    expectNoDifference(request.prompt, "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>")
    expectNoDifference(request.includeTimestamps, false)
  }

  @Test
  func `includeTimestamps false to true adds timestamps`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: false,
      content: .audio(testAudioURL)
    )
    request.includeTimestamps = true
    expectNoDifference(request.prompt, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(request.includeTimestamps, true)
  }

  @Test
  func `language getter extracts correct code`() {
    let languages: [CactusSTTLanguage] = [
      .english, .french, .german, .spanish, .chinese, .japanese, .arabic
    ]
    for language in languages {
      let request = CactusTranscription.Request(
        language: language,
        includeTimestamps: true,
        content: .audio(testAudioURL)
      )
      expectNoDifference(request.language, language, "Failed for \(language)")
    }
  }

  @Test
  func `language setter updates prompt`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    request.language = .french
    expectNoDifference(request.language, .french)
    expectNoDifference(request.prompt, "<|startoftranscript|><|fr|><|transcribe|>")
  }

  @Test
  func `language same value is no-op`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    let originalPrompt = request.prompt
    request.language = .english
    expectNoDifference(request.prompt, originalPrompt)
    expectNoDifference(request.language, .english)
  }

  @Test
  func `language change preserves timestamps`() {
    var request = CactusTranscription.Request(
      language: .english,
      includeTimestamps: true,
      content: .audio(testAudioURL)
    )
    request.language = .french
    expectNoDifference(request.prompt, "<|startoftranscript|><|fr|><|transcribe|>")
    expectNoDifference(request.includeTimestamps, true)
  }
}

private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
