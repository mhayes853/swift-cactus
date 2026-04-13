#if canImport(AVFoundation)
  import AVFoundation

  // MARK: - CactusAgentSession + AVFoundation

  extension CactusAgentSession {
    /// Prewarms the current session transcript with an optional prompt prefix and audio buffer.
    ///
    /// - Parameters:
    ///   - promptPrefix: Additional prompt content to append as a transient user message for the
    ///     prewarm operation.
    ///   - buffer: The PCM buffer to include during prewarm.
    /// - Returns: A snapshot describing what was prewarmed and the resulting metrics.
    @discardableResult
    public func prewarm(
      promptPrefix: CactusPromptContent? = nil,
      buffer: sending AVAudioPCMBuffer
    ) async throws -> Prewarm {
      try await self.prewarm(
        promptPrefix: promptPrefix,
        pcmBuffer: try buffer.cactusPCMBytes()
      )
    }

    /// Prewarms the current session transcript with a prompt prefix and audio buffer.
    ///
    /// - Parameters:
    ///   - promptPrefix: Additional prompt content to append as a transient user message for the
    ///     prewarm operation.
    ///   - buffer: The PCM buffer to include during prewarm.
    /// - Returns: A snapshot describing what was prewarmed and the resulting metrics.
    @discardableResult
    public func prewarm(
      promptPrefix: some CactusPromptRepresentable,
      buffer: sending AVAudioPCMBuffer
    ) async throws -> Prewarm {
      try await self.prewarm(
        promptPrefix: CactusPromptContent(promptPrefix),
        pcmBuffer: try buffer.cactusPCMBytes()
      )
    }

    /// Prewarms the current session transcript with a prompt-prefix builder and audio buffer.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to include during prewarm.
    ///   - promptPrefix: Additional prompt content to append as a transient user message for the
    ///     prewarm operation.
    /// - Returns: A snapshot describing what was prewarmed and the resulting metrics.
    @discardableResult
    public func prewarm(
      buffer: sending AVAudioPCMBuffer,
      @CactusPromptBuilder promptPrefix: @Sendable () -> some CactusPromptRepresentable
    ) async throws -> Prewarm {
      try await self.prewarm(
        promptPrefix: CactusPromptContent(promptPrefix()),
        pcmBuffer: try buffer.cactusPCMBytes()
      )
    }
  }
#endif
