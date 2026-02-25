// MARK: - Language Model Conversion

extension CactusUserMessage {
  /// Creates a message from prompt content and language model options.
  ///
  /// - Parameters:
  ///   - content: The prompt content for this user message.
  ///   - options: The language model options.
  ///   - maxBufferSize: The maximum buffer size used to store the completion.
  public init(
    content: CactusPromptContent,
    options: CactusLanguageModel.ChatCompletion.Options,
    maxBufferSize: Int? = nil
  ) {
    self.init(
      content: content,
      maxTokens: .limit(options.maxTokens),
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      stopSequences: options.stopSequences,
      forceFunctions: options.forceFunctions,
      toolRagTopK: options.toolRagTopK,
      includeStopSequences: options.includeStopSequences,
      isTelemetryEnabled: options.isTelemetryEnabled,
      maxBufferSize: maxBufferSize
    )
  }

  /// Creates a message from representable prompt content and language model options.
  ///
  /// - Parameters:
  ///   - content: The prompt content for this user message.
  ///   - options: The language model options.
  ///   - maxBufferSize: The maximum buffer size used to store the completion.
  public init(
    _ content: some CactusPromptRepresentable,
    options: CactusLanguageModel.ChatCompletion.Options,
    maxBufferSize: Int? = nil
  ) throws {
    try self.init(
      content.promptContent,
      maxTokens: .limit(options.maxTokens),
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      stopSequences: options.stopSequences,
      forceFunctions: options.forceFunctions,
      toolRagTopK: options.toolRagTopK,
      includeStopSequences: options.includeStopSequences,
      isTelemetryEnabled: options.isTelemetryEnabled,
      maxBufferSize: maxBufferSize
    )
  }
}
