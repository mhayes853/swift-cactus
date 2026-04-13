// MARK: - CactusUserMessage

/// A user turn payload for completion sessions.
public struct CactusUserMessage {
  /// The prompt content for this user message.
  public var content: CactusPromptContent

  /// The maximum number of tokens for the completion.
  public var maxTokens: Int

  /// The sampling temperature.
  public var temperature: Float

  /// The nucleus sampling probability.
  public var topP: Float

  /// The k most probable options to limit the next token to.
  public var topK: Int

  /// Phrases that stop generation when emitted.
  public var stopSequences: [String]

  /// Whether tool calls are forced when tools are provided.
  public var forceFunctions: Bool

  /// Number of top tools to keep after tool-RAG selection.
  public var toolRagTopK: Int

  /// Whether stop sequences are included in the response.
  public var includeStopSequences: Bool

  /// Whether telemetry is enabled for this request.
  public var isTelemetryEnabled: Bool

  /// Whether to enable thinking for models that support it.
  public var enableThinkingIfSupported: Bool

  /// The maximum buffer size used to store the completion.
  ///
  /// `nil` uses the engine default.
  public var maxBufferSize: Int?

  /// Built-in cloud-handoff behavior for this message.
  ///
  /// `nil` disables cloud handoff.
  public var cloudHandoff: CloudHandoff?

  /// PCM audio bytes to include with this message, converted to mono 16 kHz signed 16-bit PCM.
  ///
  /// Use this to send audio data alongside text content.
  public var pcmBuffer: [UInt8]?

  /// Creates a user message.
  ///
  /// - Parameters:
  ///   - content: The prompt content for this user message.
  ///   - maxTokens: The maximum number of tokens for the completion.
  ///   - temperature: Sampling temperature.
  ///   - topP: Nucleus sampling probability.
  ///   - topK: The k most probable options to limit the next token to.
  ///   - stopSequences: Phrases that stop generation when emitted.
  ///   - forceFunctions: Whether tool calls are forced when tools are provided.
  ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
  ///   - includeStopSequences: Whether stop sequences are kept in final output.
  ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
  ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
  ///   - maxBufferSize: The maximum buffer size used to store the completion.
  ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
  public init(
    content: CactusPromptContent,
    maxTokens: Int = 512,
    temperature: Float = 0.6,
    topP: Float = 0.95,
    topK: Int = 20,
    stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
    forceFunctions: Bool = false,
    toolRagTopK: Int = 2,
    includeStopSequences: Bool = false,
    isTelemetryEnabled: Bool = false,
    enableThinkingIfSupported: Bool = true,
    maxBufferSize: Int? = nil,
    cloudHandoff: CloudHandoff? = CloudHandoff(),
    pcmBuffer: [UInt8]? = nil
  ) {
    self.content = content
    self.maxTokens = maxTokens
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopSequences = stopSequences
    self.forceFunctions = forceFunctions
    self.toolRagTopK = toolRagTopK
    self.includeStopSequences = includeStopSequences
    self.isTelemetryEnabled = isTelemetryEnabled
    self.enableThinkingIfSupported = enableThinkingIfSupported
    self.maxBufferSize = maxBufferSize
    self.cloudHandoff = cloudHandoff
    self.pcmBuffer = pcmBuffer
  }

  /// Creates a user message from prompt representable content.
  ///
  /// - Parameters:
  ///   - content: The prompt content for this user message.
  ///   - maxTokens: The maximum number of tokens for the completion.
  ///   - temperature: Sampling temperature.
  ///   - topP: Nucleus sampling probability.
  ///   - topK: The k most probable options to limit the next token to.
  ///   - stopSequences: Phrases that stop generation when emitted.
  ///   - forceFunctions: Whether tool calls are forced when tools are provided.
  ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
  ///   - includeStopSequences: Whether stop sequences are kept in final output.
  ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
  ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
  ///   - maxBufferSize: The maximum buffer size used to store the completion.
  ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
  public init(
    _ content: some CactusPromptRepresentable,
    maxTokens: Int = 512,
    temperature: Float = 0.6,
    topP: Float = 0.95,
    topK: Int = 20,
    stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
    forceFunctions: Bool = false,
    toolRagTopK: Int = 2,
    includeStopSequences: Bool = false,
    isTelemetryEnabled: Bool = false,
    enableThinkingIfSupported: Bool = true,
    maxBufferSize: Int? = nil,
    cloudHandoff: CloudHandoff? = CloudHandoff(),
    pcmBuffer: [UInt8]? = nil
  ) {
    self.content = CactusPromptContent(content)
    self.maxTokens = maxTokens
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopSequences = stopSequences
    self.forceFunctions = forceFunctions
    self.toolRagTopK = toolRagTopK
    self.includeStopSequences = includeStopSequences
    self.isTelemetryEnabled = isTelemetryEnabled
    self.enableThinkingIfSupported = enableThinkingIfSupported
    self.maxBufferSize = maxBufferSize
    self.cloudHandoff = cloudHandoff
    self.pcmBuffer = pcmBuffer
  }

  /// Creates a user message from a prompt builder trailing closure.
  ///
  /// - Parameters:
  ///   - maxTokens: The maximum number of tokens for the completion.
  ///   - temperature: Sampling temperature.
  ///   - topP: Nucleus sampling probability.
  ///   - topK: The k most probable options to limit the next token to.
  ///   - stopSequences: Phrases that stop generation when emitted.
  ///   - forceFunctions: Whether tool calls are forced when tools are provided.
  ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
  ///   - includeStopSequences: Whether stop sequences are kept in final output.
  ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
  ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
  ///   - maxBufferSize: The maximum buffer size used to store the completion.
  ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
  ///   - content: The prompt content for this user message.
  public init(
    maxTokens: Int = 512,
    temperature: Float = 0.6,
    topP: Float = 0.95,
    topK: Int = 20,
    stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
    forceFunctions: Bool = false,
    toolRagTopK: Int = 2,
    includeStopSequences: Bool = false,
    isTelemetryEnabled: Bool = false,
    enableThinkingIfSupported: Bool = true,
    maxBufferSize: Int? = nil,
    cloudHandoff: CloudHandoff? = CloudHandoff(),
    pcmBuffer: [UInt8]? = nil,
    @CactusPromptBuilder content: @Sendable () -> some CactusPromptRepresentable
  ) {
    self.content = CactusPromptContent(content())
    self.maxTokens = maxTokens
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopSequences = stopSequences
    self.forceFunctions = forceFunctions
    self.toolRagTopK = toolRagTopK
    self.includeStopSequences = includeStopSequences
    self.isTelemetryEnabled = isTelemetryEnabled
    self.enableThinkingIfSupported = enableThinkingIfSupported
    self.maxBufferSize = maxBufferSize
    self.cloudHandoff = cloudHandoff
    self.pcmBuffer = pcmBuffer
  }
}

// MARK: - CloudHandoff

extension CactusUserMessage {
  /// Built-in engine cloud-handoff settings for this message.
  public struct CloudHandoff: Hashable, Sendable {
    /// Whether to include images when handing off to cloud.
    public var handoffWithImages: Bool

    /// Confidence threshold used to trigger cloud handoff.
    public var cloudHandoffThreshold: Float

    /// Timeout duration for cloud handoff.
    public var cloudTimeoutDuration: Duration

    /// Creates auto cloud-handoff settings for a user message.
    ///
    /// - Parameters:
    ///   - handoffWithImages: Whether to include images when handing off to cloud.
    ///   - cloudHandoffThreshold: Confidence threshold used to trigger cloud handoff.
    ///   - cloudTimeoutDuration: Timeout duration for cloud handoff.
    public init(
      handoffWithImages: Bool = true,
      cloudHandoffThreshold: Float = 0.7,
      cloudTimeoutDuration: Duration = .milliseconds(15000)
    ) {
      self.handoffWithImages = handoffWithImages
      self.cloudHandoffThreshold = cloudHandoffThreshold
      self.cloudTimeoutDuration = cloudTimeoutDuration
    }
  }
}
