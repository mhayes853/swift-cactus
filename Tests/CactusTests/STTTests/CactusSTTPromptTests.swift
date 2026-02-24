import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct CactusSTTPromptTests {
  @Test
  func `Prompt With Timestamps`() {
    let prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    expectNoDifference(prompt.description, "<|startoftranscript|><|en|><|transcribe|>")
  }

  @Test
  func `Prompt Without Timestamps`() {
    let prompt = CactusSTTPrompt(language: .french, includeTimestamps: false)
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>"
    )
  }

  @Test
  func `Language Getter Extracts Correct Code`() {
    let languages: [CactusSTTLanguage] = [
      .english, .french, .german, .spanish, .chinese, .japanese, .arabic
    ]
    for language in languages {
      let prompt = CactusSTTPrompt(language: language, includeTimestamps: true)
      expectNoDifference(prompt.language, language, "Failed for \(language)")
    }
  }

  @Test
  func `Language Setter Updates Prompt`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.language = .french
    expectNoDifference(prompt.language, .french)
    expectNoDifference(prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
  }

  @Test
  func `Language Same Value Is No-Op`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let originalRawValue = prompt.description
    prompt.language = .english
    expectNoDifference(prompt.description, originalRawValue)
    expectNoDifference(prompt.language, .english)
  }

  @Test
  func `Language Change Preserves Timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.language = .french
    expectNoDifference(prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `IncludeTimestamps True To True Is No-Op`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let originalRawValue = prompt.description
    prompt.includeTimestamps = true
    expectNoDifference(prompt.description, originalRawValue)
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `IncludeTimestamps True To False Removes Timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.includeTimestamps = false
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
    )
    expectNoDifference(prompt.includeTimestamps, false)
  }

  @Test
  func `IncludeTimestamps False To True Adds Timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: false)
    prompt.includeTimestamps = true
    expectNoDifference(prompt.description, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `Description Returns Prompt String`() {
    let prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    expectNoDifference(prompt.description, prompt.description)
  }

  @Test
  func `Prompt Without Previous Transcript`() {
    let prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Prompt With fullTranscript Previous Transcript`() {
    let previousTranscript = CactusTranscription.Content.fullTranscript("Hello world")
    let prompt = CactusSTTPrompt(
      language: .english,
      includeTimestamps: true,
      previousTranscript: previousTranscript
    )
    expectNoDifference(
      prompt.description,
      "<|startofprev|>Hello world<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Prompt With Timestamps Previous Transcript`() {
    let timestamps = [
      CactusTranscription.Timestamp(seconds: 0.0, transcript: "Hello"),
      CactusTranscription.Timestamp(seconds: 1.5, transcript: "world")
    ]
    let previousTranscript = CactusTranscription.Content.timestamps(timestamps)
    let prompt = CactusSTTPrompt(
      language: .english,
      includeTimestamps: true,
      previousTranscript: previousTranscript
    )
    expectNoDifference(
      prompt.description,
      "<|startofprev|><|0.00|>Hello<|1.50|>world<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Setting PreviousTranscript Updates Description`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.previousTranscript = .fullTranscript("Test")
    expectNoDifference(
      prompt.description,
      "<|startofprev|>Test<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Setting PreviousTranscript To Nil Removes Token`() {
    var prompt = CactusSTTPrompt(
      language: .english,
      includeTimestamps: true,
      previousTranscript: .fullTranscript("Test")
    )
    prompt.previousTranscript = nil
    expectNoDifference(
      prompt.description,
      "<|startoftranscript|><|en|><|transcribe|>"
    )
  }

  @Test
  func `Changing PreviousTranscript Preserves Language And Timestamps`() {
    var prompt = CactusSTTPrompt(
      language: .english,
      includeTimestamps: false,
      previousTranscript: .fullTranscript("First")
    )
    prompt.previousTranscript = .fullTranscript("Second")
    expectNoDifference(prompt.language, .english)
    expectNoDifference(prompt.includeTimestamps, false)
    expectNoDifference(
      prompt.description,
      "<|startofprev|>Second<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
    )
  }

  @Test
  func `Is Hashable`() {
    let prompt1 = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let prompt2 = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let prompt3 = CactusSTTPrompt(language: .french, includeTimestamps: true)
    expectNoDifference(prompt1, prompt2)
    #expect(prompt1 != prompt3)
  }

  @Test
  func `Parse Prompt With Startofprev And FullTranscript`() throws {
    let prompt = try #require(
      CactusSTTPrompt(
        description: "<|startofprev|>Hello world<|startoftranscript|><|en|><|transcribe|>"
      )
    )
    expectNoDifference(prompt.language, .english)
    expectNoDifference(prompt.includeTimestamps, true)
    expectNoDifference(prompt.previousTranscript, .fullTranscript("Hello world"))
  }

  @Test
  func `Parse Prompt With Startofprev And Timestamps`() throws {
    let prompt = try #require(
      CactusSTTPrompt(
        description:
          "<|startofprev|><|0.00|>Hello<|1.50|>world<|startoftranscript|><|en|><|transcribe|>"
      )
    )
    expectNoDifference(prompt.language, .english)
    expectNoDifference(prompt.includeTimestamps, true)
    expectNoDifference(
      prompt.previousTranscript,
      .timestamps([
        CactusTranscription.Timestamp(seconds: 0.0, transcript: "Hello"),
        CactusTranscription.Timestamp(seconds: 1.5, transcript: "world")
      ])
    )
  }

  @Test
  func `Parse Prompt With Startofprev And Notimestamps`() throws {
    let prompt = try #require(
      CactusSTTPrompt(
        description:
          "<|startofprev|>Previous text<|startoftranscript|><|fr|><|transcribe|><|notimestamps|>"
      )
    )
    expectNoDifference(prompt.language, .french)
    expectNoDifference(prompt.includeTimestamps, false)
    expectNoDifference(prompt.previousTranscript, .fullTranscript("Previous text"))
  }

  @Test
  func `Parse Prompt With Empty Startofprev Content`() throws {
    let prompt = try #require(
      CactusSTTPrompt(
        description: "<|startofprev|><|startoftranscript|><|en|><|transcribe|>"
      )
    )
    expectNoDifference(prompt.language, .english)
    expectNoDifference(prompt.includeTimestamps, true)
    expectNoDifference(prompt.previousTranscript, .fullTranscript(""))
  }

  @Test
  func `Parse Prompt Without Startofprev Has Nil PreviousTranscript`() throws {
    let prompt = try #require(
      CactusSTTPrompt(
        description: "<|startoftranscript|><|en|><|transcribe|>"
      )
    )
    expectNoDifference(prompt.previousTranscript, nil)
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
  fileprivate func `Init From Description Parses Valid Prompts`(testCase: ParseTestCase) {
    if let expected = testCase.expectedLanguage {
      let prompt = try! #require(CactusSTTPrompt(description: testCase.input))
      expectNoDifference(prompt.language, expected)
      expectNoDifference(prompt.includeTimestamps, testCase.expectedIncludeTimestamps)
    } else {
      let prompt = CactusSTTPrompt(description: testCase.input)
      #expect(prompt == nil)
    }
  }
}

private struct ParseTestCase: Hashable {
  let input: String
  let expectedLanguage: CactusSTTLanguage?
  let expectedIncludeTimestamps: Bool?
}
