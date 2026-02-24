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

  /// The maximum buffer size used to store the completion.
  ///
  /// `nil` uses the engine default.
  public var maxBufferSize: Int?

  /// Creates a user message.
  public init(
    content: CactusPromptContent,
    maxTokens: Int = 512,
    temperature: Float = 0.6,
    topP: Float = 0.95,
    topK: Int = 20,
    stopSequences: [String] = CactusLanguageModel.ChatCompletion.Options.defaultStopSequences,
    forceFunctions: Bool = false,
    toolRagTopK: Int = 2,
    includeStopSequences: Bool = false,
    isTelemetryEnabled: Bool = false,
    maxBufferSize: Int? = nil
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
    self.maxBufferSize = maxBufferSize
  }

  /// Creates a user message from prompt representable content.
  public init(
    _ content: some CactusPromptRepresentable,
    maxTokens: Int = 512,
    temperature: Float = 0.6,
    topP: Float = 0.95,
    topK: Int = 20,
    stopSequences: [String] = CactusLanguageModel.ChatCompletion.Options.defaultStopSequences,
    forceFunctions: Bool = false,
    toolRagTopK: Int = 2,
    includeStopSequences: Bool = false,
    isTelemetryEnabled: Bool = false,
    maxBufferSize: Int? = nil
  ) throws {
    self.content = try content.promptContent
    self.maxTokens = maxTokens
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopSequences = stopSequences
    self.forceFunctions = forceFunctions
    self.toolRagTopK = toolRagTopK
    self.includeStopSequences = includeStopSequences
    self.isTelemetryEnabled = isTelemetryEnabled
    self.maxBufferSize = maxBufferSize
  }
}
