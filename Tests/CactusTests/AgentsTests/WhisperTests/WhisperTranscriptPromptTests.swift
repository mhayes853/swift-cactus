import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `WhisperTranscriptPrompt tests` {
  @Test
  func `Prompt With Timestamps`() throws {
    let prompt = WhisperTranscribePrompt(
      language: .english,
      includeTimestamps: true,
      audioURL: testAudioURL
    )
    let components = try prompt.promptContent.messageComponents()
    expectNoDifference(components.text, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt Without Timestamps`() throws {
    let prompt = WhisperTranscribePrompt(
      language: .french,
      includeTimestamps: false,
      audioURL: testAudioURL
    )
    let components = try prompt.promptContent.messageComponents()
    expectNoDifference(components.text, "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>")
    expectNoDifference(components.images, [])
  }
}

private let testAudioURL = URL(string: "blob")!
