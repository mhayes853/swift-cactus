import Foundation

// MARK: - Request

extension CactusTranscription {
  /// Input used to perform a transcription request.
  ///
  /// A request is composed of a raw transcription prompt string, audio content,
  /// and various options for controlling the transcription behavior.
  public struct Request: Hashable, Sendable {
    /// The raw textual prompt sent to the transcription model.
    public var prompt: String

    /// The audio content to transcribe.
    public let content: Content

    /// The maximum number of tokens for the transcription.
    public var maxTokens: Int

    /// The sampling temperature.
    public var temperature: Float

    /// The nucleus sampling probability.
    public var topP: Float

    /// The k most probable options to limit the next token to.
    public var topK: Int

    /// Whether telemetry is enabled for this request.
    public var isTelemetryEnabled: Bool

    /// Whether to enable VAD weights on the transcription model.
    ///
    /// - `nil`: Use engine default behavior.
    /// - `true`: Explicitly enable VAD.
    /// - `false`: Explicitly disable VAD.
    ///
    /// When ``includeTimestamps`` is set to `true` and this property is `nil`,
    /// it will automatically be set to `true` to ensure timestamps work correctly.
    public var useVad: Bool?

    /// Threshold for triggering cloud handoff based on confidence.
    public var cloudHandoffThreshold: Float?

    /// The maximum buffer size for the transcription.
    ///
    /// `nil` uses the engine default (8192).
    public var maxBufferSize: Int?

    /// The language code extracted from the prompt.
    public var language: CactusSTTLanguage {
      get {
        let prompt = self.prompt
        guard let sotRange = prompt.range(of: "<|startoftranscript|>") else { return .english }
        let searchStart = sotRange.upperBound
        guard let langStart = prompt.range(of: "<|", range: searchStart..<prompt.endIndex),
          let langEnd = prompt.range(of: "|>", range: langStart.upperBound..<prompt.endIndex)
        else {
          return .english
        }
        let languageCode = String(prompt[langStart.upperBound..<langEnd.lowerBound])
        return CactusSTTLanguage(rawValue: languageCode)
      }
      set {
        let prompt = self.prompt
        guard let sotRange = prompt.range(of: "<|startoftranscript|>") else { return }
        let searchStart = sotRange.upperBound
        guard let langStart = prompt.range(of: "<|", range: searchStart..<prompt.endIndex),
          let langEnd = prompt.range(of: "|>", range: langStart.upperBound..<prompt.endIndex)
        else {
          return
        }
        self.prompt.replaceSubrange(
          langStart.upperBound..<langEnd.lowerBound,
          with: newValue.rawValue
        )
      }
    }

    /// Whether the prompt includes timestamp tokens.
    ///
    /// When setting to `true`, if ``useVad`` is `nil`, it will automatically be set
    /// to `true` to ensure timestamps work correctly.
    public var includeTimestamps: Bool {
      get {
        !prompt.contains("<|notimestamps|>")
      }
      set {
        if newValue {
          prompt = prompt.replacingOccurrences(of: "<|notimestamps|>", with: "")
          if useVad == nil {
            useVad = true
          }
        } else {
          if !prompt.contains("<|notimestamps|>") {
            prompt += "<|notimestamps|>"
          }
        }
      }
    }

    /// Creates a transcription request from a raw prompt and content.
    ///
    /// If the prompt does not contain `<|notimestamps|>` and `useVad` is `nil`,
    /// ``useVad`` will automatically be set to `true` to ensure timestamps work correctly.
    ///
    /// - Parameters:
    ///   - prompt: The exact prompt string to send to the model.
    ///   - content: The audio content to transcribe.
    ///   - maxTokens: The maximum number of tokens for the transcription.
    ///   - temperature: The sampling temperature.
    ///   - topP: The nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - isTelemetryEnabled: Whether telemetry is enabled.
    ///   - useVad: Whether to enable VAD weights.
    ///   - cloudHandoffThreshold: Optional confidence threshold for cloud handoff.
    ///   - maxBufferSize: The maximum buffer size for the transcription.
    public init(
      prompt: String,
      content: Content,
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      isTelemetryEnabled: Bool = false,
      useVad: Bool? = nil,
      cloudHandoffThreshold: Float? = nil,
      maxBufferSize: Int? = nil
    ) {
      self.prompt = prompt
      self.content = content
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.isTelemetryEnabled = isTelemetryEnabled
      self.cloudHandoffThreshold = cloudHandoffThreshold
      self.maxBufferSize = maxBufferSize

      if let useVad {
        self.useVad = useVad
      } else if !prompt.contains("<|notimestamps|>") {
        self.useVad = true
      } else {
        self.useVad = nil
      }
    }

    /// Creates a transcription request from language/timestamp configuration.
    ///
    /// The generated prompt follows Whisper token formatting:
    /// `<|startoftranscript|><|{language}|><|transcribe|>[<|notimestamps|>]`.
    ///
    /// If `includeTimestamps` is `true` and `useVad` is `nil`, ``useVad`` will
    /// automatically be set to `true` to ensure timestamps work correctly.
    ///
    /// - Parameters:
    ///   - language: The language code token to include in the prompt.
    ///   - includeTimestamps: Whether timestamp tags should be included in output.
    ///   - content: The audio content to transcribe.
    ///   - maxTokens: The maximum number of tokens for the transcription.
    ///   - temperature: The sampling temperature.
    ///   - topP: The nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - isTelemetryEnabled: Whether telemetry is enabled.
    ///   - useVad: Whether to enable VAD weights.
    ///   - cloudHandoffThreshold: cloud handoff.
    ///   - maxBufferSize: The maximum buffer size Optional confidence threshold for for the transcription.
    public init(
      language: CactusSTTLanguage,
      includeTimestamps: Bool,
      content: Content,
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      isTelemetryEnabled: Bool = false,
      useVad: Bool? = nil,
      cloudHandoffThreshold: Float? = nil,
      maxBufferSize: Int? = nil
    ) {
      self.init(
        prompt: Self.prompt(language: language, includeTimestamps: includeTimestamps),
        content: content,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        isTelemetryEnabled: isTelemetryEnabled,
        useVad: useVad,
        cloudHandoffThreshold: cloudHandoffThreshold,
        maxBufferSize: maxBufferSize
      )
    }

    private static func prompt(
      language: CactusSTTLanguage,
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
