import Foundation

// MARK: - Request

extension CactusTranscription {
  /// Input used to perform a transcription request.
  ///
  /// A request is composed of a transcription prompt, audio content,
  /// and various options for controlling the transcription behavior.
  public struct Request: Hashable, Sendable {
    /// The transcription prompt encoding language and timestamp configuration.
    public var prompt: CactusSTTPrompt {
      didSet {
        if prompt.includeTimestamps && useVad == nil {
          useVad = true
        }
      }
    }

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

    /// Creates a transcription request from a prompt and content.
    ///
    /// If the prompt includes timestamps and `useVad` is `nil`,
    /// ``useVad`` will automatically be set to `true` to ensure timestamps work correctly.
    ///
    /// - Parameters:
    ///   - prompt: The transcription prompt encoding language and timestamp configuration.
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
      prompt: CactusSTTPrompt,
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
      } else if prompt.includeTimestamps {
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
      let prompt = CactusSTTPrompt(language: language, includeTimestamps: includeTimestamps)
      self.init(
        prompt: prompt,
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
