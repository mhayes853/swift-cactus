// MARK: - Language Model Conversion

extension CactusUserMessage {
  /// Converts this message's flattened settings to language model options.
  public var chatCompletionOptions: CactusLanguageModel.ChatCompletion.Options {
    CactusLanguageModel.ChatCompletion.Options(
      maxTokens: self.maxTokens,
      temperature: self.temperature,
      topP: self.topP,
      topK: self.topK,
      stopSequences: self.stopSequences,
      forceFunctions: self.forceFunctions,
      confidenceThreshold: -1.0,  // TODO: Supports cloud handoff for agent sessions.
      toolRagTopK: self.toolRagTopK,
      includeStopSequences: self.includeStopSequences,
      isTelemetryEnabled: self.isTelemetryEnabled
    )
  }

  /// Creates a message from prompt content and language model options.
  public init(
    content: CactusPromptContent,
    options: CactusLanguageModel.ChatCompletion.Options,
    maxBufferSize: Int? = nil
  ) {
    self.content = content
    self.maxTokens = options.maxTokens
    self.temperature = options.temperature
    self.topP = options.topP
    self.topK = options.topK
    self.stopSequences = options.stopSequences
    self.forceFunctions = options.forceFunctions
    self.toolRagTopK = options.toolRagTopK
    self.includeStopSequences = options.includeStopSequences
    self.isTelemetryEnabled = options.isTelemetryEnabled
    self.maxBufferSize = maxBufferSize
  }

  /// Creates a message from representable prompt content and language model options.
  public init(
    _ content: some CactusPromptRepresentable,
    options: CactusLanguageModel.ChatCompletion.Options,
    maxBufferSize: Int? = nil
  ) throws {
    self.content = try content.promptContent
    self.maxTokens = options.maxTokens
    self.temperature = options.temperature
    self.topP = options.topP
    self.topK = options.topK
    self.stopSequences = options.stopSequences
    self.forceFunctions = options.forceFunctions
    self.toolRagTopK = options.toolRagTopK
    self.includeStopSequences = options.includeStopSequences
    self.isTelemetryEnabled = options.isTelemetryEnabled
    self.maxBufferSize = maxBufferSize
  }
}
