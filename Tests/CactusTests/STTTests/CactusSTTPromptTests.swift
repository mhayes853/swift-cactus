import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct CactusSTTPromptTests {
  @Test
  func `Default Prompt Returns Empty String`() {
    let prompt = CactusSTTPrompt.default
    expectNoDifference(prompt.description, "")
  }

  @Test
  func `Whisper Prompt With Timestamps`() {
    let whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(prompt.description, "<|startoftranscript|><|en|><|transcribe|>")
  }

  @Test
  func `Whisper Prompt Without Timestamps`() {
    let whisper = CactusSTTPrompt.Whisper(language: .french, includeTimestamps: false)
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>"
    )
  }

  @Test
  func `Whisper Language Getter Extracts Correct Code`() {
    let languages: [CactusSTTLanguage] = [
      .english, .french, .german, .spanish, .chinese, .japanese, .arabic
    ]
    for language in languages {
      let whisper = CactusSTTPrompt.Whisper(language: language, includeTimestamps: true)
      expectNoDifference(whisper.language, language, "Failed for \(language)")
    }
  }

  @Test
  func `Whisper Language Setter Updates Prompt`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    whisper.language = .french
    expectNoDifference(whisper.language, .french)
    expectNoDifference(whisper.description, "<|startoftranscript|><|fr|><|transcribe|>")
  }

  @Test
  func `Whisper Language Same Value Is No-Op`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let originalRawValue = whisper.description
    whisper.language = .english
    expectNoDifference(whisper.description, originalRawValue)
    expectNoDifference(whisper.language, .english)
  }

  @Test
  func `Whisper Language Change Preserves Timestamps`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    whisper.language = .french
    expectNoDifference(whisper.description, "<|startoftranscript|><|fr|><|transcribe|>")
    expectNoDifference(whisper.includeTimestamps, true)
  }

  @Test
  func `Whisper IncludeTimestamps True To True Is No-Op`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let originalRawValue = whisper.description
    whisper.includeTimestamps = true
    expectNoDifference(whisper.description, originalRawValue)
    expectNoDifference(whisper.includeTimestamps, true)
  }

  @Test
  func `Whisper IncludeTimestamps True To False Removes Timestamps`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    whisper.includeTimestamps = false
    expectNoDifference(
      whisper.description,
      "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
    )
    expectNoDifference(whisper.includeTimestamps, false)
  }

  @Test
  func `Whisper IncludeTimestamps False To True Adds Timestamps`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: false)
    whisper.includeTimestamps = true
    expectNoDifference(whisper.description, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(whisper.includeTimestamps, true)
  }

  @Test
  func `Whisper Description Returns Prompt String`() {
    let whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(prompt.description, whisper.description)
  }

  @Test
  func `Whisper Without Previous Transcript`() {
    let whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Whisper With Previous Transcript String`() {
    let whisper = CactusSTTPrompt.Whisper(
      language: .english,
      includeTimestamps: true,
      previousTranscript: "Hello world"
    )
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(
      prompt.description,
      "<|startofprev|>Hello world<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Whisper Setting PreviousTranscript Updates Description`() {
    var whisper = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    whisper.previousTranscript = "Test"
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(
      prompt.description,
      "<|startofprev|>Test<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Whisper Setting PreviousTranscript To Nil Removes Token`() {
    var whisper = CactusSTTPrompt.Whisper(
      language: .english,
      includeTimestamps: true,
      previousTranscript: "Test"
    )
    whisper.previousTranscript = nil
    let prompt = CactusSTTPrompt.whisper(whisper)
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Whisper Changing PreviousTranscript Preserves Language And Timestamps`() {
    var whisper = CactusSTTPrompt.Whisper(
      language: .english,
      includeTimestamps: false,
      previousTranscript: "First"
    )
    whisper.previousTranscript = "Second"
    expectNoDifference(whisper.language, .english)
    expectNoDifference(whisper.includeTimestamps, false)
    expectNoDifference(
      whisper.description,
      "<|startofprev|>Second<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
    )
  }

  @Test
  func `Is Hashable`() {
    let whisper1 = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let whisper2 = CactusSTTPrompt.Whisper(language: .english, includeTimestamps: true)
    let whisper3 = CactusSTTPrompt.Whisper(language: .french, includeTimestamps: true)
    let prompt1 = CactusSTTPrompt.whisper(whisper1)
    let prompt2 = CactusSTTPrompt.whisper(whisper2)
    let prompt3 = CactusSTTPrompt.whisper(whisper3)
    expectNoDifference(prompt1, prompt2)
    #expect(prompt1 != prompt3)
  }

  @Test
  func `Default Prompt Is Hashable`() {
    let prompt1 = CactusSTTPrompt.default
    let prompt2 = CactusSTTPrompt.default
    expectNoDifference(prompt1, prompt2)
  }

  @Test
  func `Parse Empty Description Returns Default`() {
    let prompt = CactusSTTPrompt.whisper(prompt: "")
    #expect(prompt == .default)
  }

  @Test
  func `Parse Prompt With Startofprev And Transcript`() throws {
    let prompt = try #require(
      CactusSTTPrompt.whisper(
        prompt: "<|startofprev|>Hello world<|startoftranscript|><|en|><|transcribe|>"
      )
    )
    guard case .whisper(let whisper) = prompt else {
      throw TestError("Expected whisper case")
    }
    expectNoDifference(whisper.language, .english)
    expectNoDifference(whisper.includeTimestamps, true)
    expectNoDifference(whisper.previousTranscript, "Hello world")
  }

  @Test
  func `Parse Prompt With Timestamps In Previous Transcript`() throws {
    let prompt = try #require(
      CactusSTTPrompt.whisper(
        prompt: "<|startofprev|><|0.00|>Hello<|1.50|>world<|startoftranscript|><|en|><|transcribe|>"
      )
    )
    guard case .whisper(let whisper) = prompt else {
      throw TestError("Expected whisper case")
    }
    expectNoDifference(whisper.language, .english)
    expectNoDifference(whisper.includeTimestamps, true)
    expectNoDifference(
      whisper.previousTranscript,
      "<|0.00|>Hello<|1.50|>world"
    )
  }

  @Test
  func `Parse Prompt With Startofprev And Notimestamps`() throws {
    let prompt = try #require(
      CactusSTTPrompt.whisper(
        prompt:
          "<|startofprev|>Previous text<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>"
      )
    )
    guard case .whisper(let whisper) = prompt else {
      throw TestError("Expected whisper case")
    }
    expectNoDifference(whisper.language, .french)
    expectNoDifference(whisper.includeTimestamps, false)
    expectNoDifference(whisper.previousTranscript, "Previous text")
  }

  @Test
  func `Parse Prompt With Empty Startofprev Content`() throws {
    let prompt = try #require(
      CactusSTTPrompt.whisper(prompt: "<|startofprev|><|startoftranscript|><|en|><|transcribe|>")
    )
    guard case .whisper(let whisper) = prompt else {
      throw TestError("Expected whisper case")
    }
    expectNoDifference(whisper.language, .english)
    expectNoDifference(whisper.includeTimestamps, true)
    expectNoDifference(whisper.previousTranscript, "")
  }

  @Test
  func `Parse Prompt Without Startofprev Has Nil PreviousTranscript`() throws {
    let prompt = try #require(
      CactusSTTPrompt.whisper(prompt: "<|startoftranscript|><|en|><|transcribe|>")
    )
    guard case .whisper(let whisper) = prompt else {
      throw TestError("Expected whisper case")
    }
    expectNoDifference(whisper.previousTranscript, nil)
  }

  @Test(
    arguments: [
      ParseTestCase(
        input: "<|startoftranscript|><|en|><|transcribe|>",
        expectedLanguage: .english,
        expectedIncludeTimestamps: true
      ),
      ParseTestCase(
        input: "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>",
        expectedLanguage: .french,
        expectedIncludeTimestamps: false
      ),
      ParseTestCase(
        input: "<|startoftranscript|><|EN|><|transcribe|>",
        expectedLanguage: .english,
        expectedIncludeTimestamps: true
      ),
      ParseTestCase(
        input: "<|startoftranscript|><|zh|><|transcribe|><|NOTIMESTAMPS|>",
        expectedLanguage: .chinese,
        expectedIncludeTimestamps: false
      ),
      ParseTestCase(
        input: "<|STARTOFTRANSCRIPT|><|de|><|TRANSCRIBE|>",
        expectedLanguage: .german,
        expectedIncludeTimestamps: true
      ),
      ParseTestCase(
        input: "<|startoftranscript|>",
        expectedLanguage: nil,
        expectedIncludeTimestamps: nil
      ),
      ParseTestCase(
        input: "<|startoftranscript|><||><|transcribe|>",
        expectedLanguage: nil,
        expectedIncludeTimestamps: nil
      ),
      ParseTestCase(
        input: "random text",
        expectedLanguage: nil,
        expectedIncludeTimestamps: nil
      ),
      ParseTestCase(
        input: "<|startoftranscript|><|en|>",
        expectedLanguage: nil,
        expectedIncludeTimestamps: nil
      )
    ]
  )
  fileprivate func `Init From Description Parses Valid Prompts`(testCase: ParseTestCase) throws {
    if let expected = testCase.expectedLanguage {
      let prompt = try #require(CactusSTTPrompt.whisper(prompt: testCase.input))
      guard case .whisper(let whisper) = prompt else {
        throw TestError("Expected whisper case")
      }
      expectNoDifference(whisper.language, expected)
      expectNoDifference(whisper.includeTimestamps, testCase.expectedIncludeTimestamps)
    } else {
      let prompt = CactusSTTPrompt.whisper(prompt: testCase.input)
      expectNoDifference(prompt, nil)
    }
  }
}

private struct ParseTestCase: Hashable {
  let input: String
  let expectedLanguage: CactusSTTLanguage?
  let expectedIncludeTimestamps: Bool?
}

private enum TestError: Error {
  case message(String)

  init(_ message: String) {
    self = .message(message)
  }
}
