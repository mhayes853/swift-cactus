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
  func `language getter extracts correct code`() {
    let languages: [CactusSTTLanguage] = [
      .english, .french, .german, .spanish, .chinese, .japanese, .arabic
    ]
    for language in languages {
      let prompt = CactusSTTPrompt(language: language, includeTimestamps: true)
      expectNoDifference(prompt.language, language, "Failed for \(language)")
    }
  }

  @Test
  func `language setter updates prompt`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.language = .french
    expectNoDifference(prompt.language, .french)
    expectNoDifference(prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
  }

  @Test
  func `language same value is no-op`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let originalRawValue = prompt.description
    prompt.language = .english
    expectNoDifference(prompt.description, originalRawValue)
    expectNoDifference(prompt.language, .english)
  }

  @Test
  func `language change preserves timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.language = .french
    expectNoDifference(prompt.description, "<|startoftranscript|><|fr|><|transcribe|>")
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `includeTimestamps true to true is no-op`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let originalRawValue = prompt.description
    prompt.includeTimestamps = true
    expectNoDifference(prompt.description, originalRawValue)
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `includeTimestamps true to false removes timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    prompt.includeTimestamps = false
    expectNoDifference(prompt.description, "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>")
    expectNoDifference(prompt.includeTimestamps, false)
  }

  @Test
  func `includeTimestamps false to true adds timestamps`() {
    var prompt = CactusSTTPrompt(language: .english, includeTimestamps: false)
    prompt.includeTimestamps = true
    expectNoDifference(prompt.description, "<|startoftranscript|><|en|><|transcribe|>")
    expectNoDifference(prompt.includeTimestamps, true)
  }

  @Test
  func `description returns prompt string`() {
    let prompt = CactusSTTPrompt(language: .english, includeTimestamps: true)
    expectNoDifference(prompt.description, prompt.description)
  }

  @Test
  func `is hashable`() {
    let prompt1 = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let prompt2 = CactusSTTPrompt(language: .english, includeTimestamps: true)
    let prompt3 = CactusSTTPrompt(language: .french, includeTimestamps: true)
    expectNoDifference(prompt1, prompt2)
    #expect(prompt1 != prompt3)
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
      ),
    ]
  )
  fileprivate func `init from description parses valid prompts`(testCase: ParseTestCase) {
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
