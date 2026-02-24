import Foundation

// MARK: - CactusSTTPrompt

/// A transcription prompt that encodes language and timestamp configuration.
public struct CactusSTTPrompt: Hashable, Sendable, CustomStringConvertible {
  /// The language code for the transcription.
  public var language: CactusSTTLanguage

  /// Whether the prompt should include timestamp tokens in the output.
  public var includeTimestamps: Bool

  /// Previous transcription content to include as context.
  public var previousTranscript: CactusTranscription.Content?

  /// The raw prompt text.
  public var description: String {
    var prompt = ""
    if let previousTranscript = previousTranscript {
      prompt += "<|startofprev|>\(previousTranscript.response)"
    }
    prompt += "<|startoftranscript|><|\(language.rawValue)|><|transcribe|>"
    if !includeTimestamps {
      prompt += "<|notimestamps|>"
    }
    return prompt
  }

  /// Creates a transcription prompt from language and timestamp configuration.
  ///
  /// - Parameters:
  ///   - language: The language code token to include in the prompt.
  ///   - includeTimestamps: Whether timestamp tags should be included in output.
  ///   - previousTranscript: Optional previous transcription content to include as context.
  public init(
    language: CactusSTTLanguage,
    includeTimestamps: Bool,
    previousTranscript: CactusTranscription.Content? = nil
  ) {
    self.language = language
    self.includeTimestamps = includeTimestamps
    self.previousTranscript = previousTranscript
  }

  /// Creates a transcription prompt from a text description string.
  ///
  /// Returns `nil` if the string is not a valid Whisper-style transcription prompt.
  /// Valid format: `[<|startofprev|>{content}]<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`
  ///
  /// - Parameter description: The prompt string to parse.
  public init?(description: String) {
    guard promptRegex.matches(description) else { return nil }

    let groups = promptRegex.matchGroups(from: description)
    guard groups.count >= 1 else { return nil }

    let rawLanguage = String(groups[0])
    let language = CactusSTTLanguage(rawValue: rawLanguage.lowercased())

    let previousTranscript: CactusTranscription.Content?
    if let startOfPrev = description.range(of: startOfPrevToken, options: [.caseInsensitive]),
      let startOfTranscript = description.range(
        of: startOfTranscriptToken,
        options: [.caseInsensitive]
      ),
      startOfPrev.lowerBound < startOfTranscript.lowerBound
    {
      let transcript = String(description[startOfPrev.upperBound..<startOfTranscript.lowerBound])
      previousTranscript = CactusTranscription.Content(response: transcript)
    } else {
      previousTranscript = nil
    }

    let includeTimestamps = !description.lowercased().hasSuffix(notimestampsToken)

    self.language = language
    self.includeTimestamps = includeTimestamps
    self.previousTranscript = previousTranscript
  }
}

private let promptRegex = try! RegularExpression(
  #"(?i)^(?:<\|startofprev\|>[\s\S]*?)?<\|startoftranscript\|><\|([a-zA-Z]+)\|><\|transcribe\|>(?:<\|notimestamps\|>)?$"#
)

private let startOfPrevToken = "<|startofprev|>"
private let startOfTranscriptToken = "<|startoftranscript|>"
private let notimestampsToken = "<|notimestamps|>"
