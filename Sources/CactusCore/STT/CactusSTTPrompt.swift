import Foundation

// MARK: - CactusSTTPrompt

/// A transcription prompt that encodes language and timestamp configuration.
public struct CactusSTTPrompt: Hashable, Sendable, CustomStringConvertible {
  /// The language code for the transcription.
  public var language: CactusSTTLanguage

  /// Whether the prompt should include timestamp tokens in the output.
  public var includeTimestamps: Bool

  /// The raw prompt text.
  public var description: String {
    var prompt = "<|startoftranscript|><|\(language.rawValue)|><|transcribe|>"
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
  public init(language: CactusSTTLanguage, includeTimestamps: Bool) {
    self.language = language
    self.includeTimestamps = includeTimestamps
  }

  /// Creates a transcription prompt from a text description string.
  ///
  /// Returns `nil` if the string is not a valid Whisper-style transcription prompt.
  /// Valid format: `<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`
  ///
  /// - Parameter description: The prompt string to parse.
  public init?(description: String) {
    guard promptRegex.matches(description) else { return nil }

    let groups = promptRegex.matchGroups(from: description)
    guard
      let language = groups.first.map({ String($0) })
        .flatMap({ CactusSTTLanguage(rawValue: $0.lowercased()) })
    else {
      return nil
    }

    let hasNoTimestamps = groups.count > 1
    self.language = language
    self.includeTimestamps = !hasNoTimestamps
  }
}

private let promptRegex = try! RegularExpression(
  #"(?i)<\|startoftranscript\|><\|([a-zA-Z]+)\|><\|transcribe\|>(<\|notimestamps\|>)?"#
)
