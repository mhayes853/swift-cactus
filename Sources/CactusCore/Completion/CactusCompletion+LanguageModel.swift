// MARK: - Language Model Conversion

extension CactusCompletionEntry {
  /// Creates a completion entry from a transcript element and chat completion metrics.
  public init(
    transcriptEntry: CactusTranscript.Element,
    completion: CactusLanguageModel.ChatCompletion
  ) {
    self.init(
      transcriptEntry: transcriptEntry,
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
