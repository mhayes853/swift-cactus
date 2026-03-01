extension CactusModel.Completion.Options {
  /// Creates completion options from a user message.
  ///
  /// - Parameter message: The user message request.
  public init(message: CactusUserMessage) {
    let cloudHandoffThreshold = message.cloudHandoff?.cloudHandoffThreshold ?? 0
    let cloudTimeoutDuration =
      message.cloudHandoff?.cloudTimeoutDuration
      ?? .milliseconds(15000)
    let handoffWithImages = message.cloudHandoff?.handoffWithImages ?? false

    self.init(
      maxTokens: message.maxTokens,
      temperature: message.temperature,
      topP: message.topP,
      topK: message.topK,
      stopSequences: message.stopSequences,
      forceFunctions: message.forceFunctions,
      cloudHandoffThreshold: cloudHandoffThreshold,
      toolRagTopK: message.toolRagTopK,
      includeStopSequences: message.includeStopSequences,
      isTelemetryEnabled: message.isTelemetryEnabled,
      autoHandoff: message.cloudHandoff != nil,
      cloudTimeoutDuration: cloudTimeoutDuration,
      handoffWithImages: handoffWithImages
    )
  }
}
