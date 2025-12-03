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
      audioURL: .testAudio
    )
    let components = try prompt.defaultMessageComponents()
    expectNoDifference(components.text, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt Without Timestamps`() throws {
    let prompt = WhisperTranscribePrompt(
      language: .french,
      includeTimestamps: false,
      audioURL: .testAudio
    )
    let components = try prompt.defaultMessageComponents()
    expectNoDifference(components.text, "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>")
    expectNoDifference(components.images, [])
  }
}
