import Foundation

// MARK: - Request

extension CactusTranscription {
  /// Input used to perform a transcription request.
  ///
  /// A request is composed of a raw transcription prompt string and exactly one
  /// audio content source contained in ``Content``.
  public struct Request: Hashable, Sendable {
    /// The raw textual prompt sent to the transcription model.
    public let prompt: String

    /// The audio content to transcribe.
    public let content: Content

    /// Creates a transcription request from a raw prompt and content.
    ///
    /// - Parameters:
    ///   - prompt: The exact prompt string to send to the model.
    ///   - content: The audio content to transcribe.
    public init(prompt: String, content: Content) {
      self.prompt = prompt
      self.content = content
    }

    /// Creates a transcription request from language/timestamp configuration.
    ///
    /// The generated prompt follows Whisper token formatting:
    /// `<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`.
    ///
    /// - Parameters:
    ///   - language: The language code token to include in the prompt.
    ///   - includeTimestamps: Whether timestamp tags should be included in output.
    ///   - content: The audio content to transcribe.
    public init(
      language: CactusTranscriptionLanguage,
      includeTimestamps: Bool,
      content: Content
    ) {
      self.prompt = Self.prompt(language: language, includeTimestamps: includeTimestamps)
      self.content = content
    }

    private static func prompt(
      language: CactusTranscriptionLanguage,
      includeTimestamps: Bool
    ) -> String {
      var prompt = "<|startoftranscript|><|\(language.rawValue)|><|transcribe|>"
      if !includeTimestamps {
        prompt += "<|notimestamps|>"
      }
      return prompt
    }
  }
}

// MARK: - Content

extension CactusTranscription.Request {
  /// The audio payload for a transcription request.
  ///
  /// Construct instances with ``audio(_:)`` or ``pcm(_:)``.
  public struct Content: Hashable, Sendable {
    /// The audio file URL to transcribe, when file-based input is used.
    public let audioURL: URL?

    /// Raw PCM bytes to transcribe, when in-memory PCM input is used.
    public let pcmBytes: [UInt8]?

    private init(audioURL: URL?, pcmBytes: [UInt8]?) {
      self.audioURL = audioURL
      self.pcmBytes = pcmBytes
    }

    /// Creates content from an audio file URL.
    ///
    /// - Parameter url: The local audio file URL.
    /// - Returns: Content configured for file-based transcription.
    public static func audio(_ url: URL) -> Self {
      Self(audioURL: url, pcmBytes: nil)
    }

    /// Creates content from raw PCM bytes.
    ///
    /// - Parameter bytes: PCM bytes expected by the transcription engine.
    /// - Returns: Content configured for PCM-based transcription.
    public static func pcm(_ bytes: [UInt8]) -> Self {
      Self(audioURL: nil, pcmBytes: bytes)
    }
  }
}
