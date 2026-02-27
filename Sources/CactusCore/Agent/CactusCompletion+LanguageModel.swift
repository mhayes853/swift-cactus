// MARK: - Language Model Conversion

extension CactusCompletionEntry {
  /// Creates a completion entry from a transcript element and chat completion metrics.
  ///
  /// - Parameters:
  ///   - transcriptEntry: The transcript element to associate with this completion.
  ///   - completion: The chat completion metrics from the language model.
  public init(
    transcriptEntry: CactusTranscript.Element,
    completion: CactusLanguageModel.ChatCompletion
  ) {
    self.init(transcriptEntry: transcriptEntry, metrics: .init(completion: completion))
  }
}

extension CactusCompletionEntry.Metrics {
  /// Creates completion entry metrics from language model chat completion metrics.
  ///
  /// - Parameter completion: The chat completion metrics from the language model.
  public init(completion: CactusLanguageModel.ChatCompletion) {
    self.init(
      prefillTokens: completion.prefillTokens,
      decodeTokens: completion.decodeTokens,
      totalTokens: completion.totalTokens,
      confidence: completion.confidence,
      prefillTps: completion.prefillTps,
      decodeTps: completion.decodeTps,
      ramUsageMb: completion.ramUsageMb,
      durationToFirstToken: .seconds(completion.timeIntervalToFirstToken),
      totalDuration: .seconds(completion.totalTimeInterval)
    )
  }
}
