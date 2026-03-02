import Foundation

// MARK: - CactusSTTPrompt

/// A transcription prompt that encodes language and timestamp configuration.
public enum CactusSTTPrompt: Hashable, Sendable, CustomStringConvertible {
  /// A default prompt.
  case `default`

  /// A Whisper-style prompt.
  case whisper(Whisper)

  /// Whisper-specific prompt configuration.
  public struct Whisper: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    /// The language code for the transcription.
    public var language: CactusSTTLanguage

    /// Whether the prompt should include timestamp tokens in the output.
    public var includeTimestamps: Bool

    /// Previous transcript text to include as context.
    public var previousTranscript: String?

    public var rawValue: String {
      var prompt = ""
      if let previousTranscript = previousTranscript, !previousTranscript.isEmpty {
        prompt += "<|startofprev|>\(previousTranscript)"
      }
      prompt += "<|startoftranscript|><|\(language.rawValue)|><|transcribe|>"
      if !includeTimestamps {
        prompt += "<|notimestamps|>"
      }
      return prompt
    }

    public var description: String {
      self.rawValue
    }

    /// Creates a Whisper prompt from language and timestamp configuration.
    ///
    /// - Parameters:
    ///   - language: The language code token to include in the prompt.
    ///   - includeTimestamps: Whether timestamp tags should be included in output.
    ///   - previousTranscript: Optional previous transcript text to include as context.
    public init(
      language: CactusSTTLanguage,
      includeTimestamps: Bool,
      previousTranscript: String? = nil
    ) {
      self.language = language
      self.includeTimestamps = includeTimestamps
      self.previousTranscript = previousTranscript
    }
  }

  /// The raw prompt text.
  public var description: String {
    switch self {
    case .default: ""
    case .whisper(let whisper): whisper.description
    }
  }

  /// Creates a Whisper prompt from language and timestamp configuration.
  ///
  /// - Parameters:
  ///   - language: The language code token to include in the prompt.
  ///   - includeTimestamps: Whether timestamp tags should be included in output.
  ///   - previousTranscript: Optional previous transcript text to include as context.
  public static func whisper(
    language: CactusSTTLanguage,
    includeTimestamps: Bool,
    previousTranscript: String? = nil
  ) -> Self {
    .whisper(
      Whisper(
        language: language,
        includeTimestamps: includeTimestamps,
        previousTranscript: previousTranscript
      )
    )
  }

  /// Creates a Whisper prompt from a prompt string.
  ///
  /// Returns `nil` if the string is not a valid Whisper-style transcription prompt.
  /// Valid format: `[<|startofprev|>{content}]<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`
  ///
  /// - Parameter prompt: The prompt string to parse.
  public static func whisper(prompt: String) -> Self? {
    Whisper(rawValue: prompt).flatMap { .whisper($0) }
  }
}

// MARK: - CactusSTTPrompt.Whisper

extension CactusSTTPrompt.Whisper {
  /// Creates a Whisper prompt from a text description string.
  ///
  /// Returns `nil` if the string is not a valid Whisper-style transcription prompt.
  /// Valid format: `[<|startofprev|>{content}]<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`
  ///
  /// - Parameter rawValue: The whisper-style prompt string to parse.
  public init?(rawValue: String) {
    guard !rawValue.isEmpty else { return nil }

    guard promptRegex.matches(rawValue) else { return nil }

    let groups = promptRegex.matchGroups(from: rawValue)
    guard groups.count >= 1 else { return nil }

    let rawLanguage = String(groups[0])
    let language = CactusSTTLanguage(rawValue: rawLanguage.lowercased())

    let previousTranscript: String?
    if let startOfPrev = rawValue.range(of: startOfPrevToken, options: [.caseInsensitive]),
      let startOfTranscript = rawValue.range(
        of: startOfTranscriptToken,
        options: [.caseInsensitive]
      ),
      startOfPrev.lowerBound < startOfTranscript.lowerBound
    {
      previousTranscript = String(
        rawValue[startOfPrev.upperBound..<startOfTranscript.lowerBound]
      )
    } else {
      previousTranscript = nil
    }

    let includeTimestamps = !rawValue.lowercased().hasSuffix(notimestampsToken)

    self.init(
      language: language,
      includeTimestamps: includeTimestamps,
      previousTranscript: previousTranscript
    )
  }
}

private let promptRegex = try! RegularExpression(
  #"(?i)^(?:<\|startofprev\|>[\s\S]*?)?<\|startoftranscript\|><\|([a-zA-Z]+)\|><\|transcribe\|>(?:<\|notimestamps\|>)?$"#
)

private let startOfPrevToken = "<|startofprev|>"
private let startOfTranscriptToken = "<|startoftranscript|>"
private let notimestampsToken = "<|notimestamps|>"
