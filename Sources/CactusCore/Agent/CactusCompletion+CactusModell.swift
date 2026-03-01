// MARK: - Language Model Conversion

extension CactusCompletionEntry {
  /// Creates a completion entry from a transcript element and chat completion metrics.
  ///
  /// - Parameters:
  ///   - transcriptEntry: The transcript element to associate with this completion.
  ///   - completion: The chat completion metrics from the language model.
  public init(
    transcriptEntry: CactusTranscript.Element,
    completion: CactusModel.Completion
  ) {
    self.init(
      transcriptEntry: transcriptEntry,
      metrics: CactusGenerationMetrics(completion: completion)
    )
  }
}
