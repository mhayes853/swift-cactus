#if canImport(AVFoundation)
  import AVFoundation

  // MARK: - CactusLanguageModelActor + AVFoundation

  extension CactusLanguageModelActor {
    /// Transcribes the specified PCM buffer.
    ///
    /// The buffer is converted to cactus-compatible mono 16 kHz PCM bytes using the default audio format conversion.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to transcribe.
    ///   - prompt: The prompt to use for transcription.
    ///   - options: The ``CactusLanguageModel/Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusLanguageModel/Transcription``.
    public func transcribe(
      buffer: sending AVAudioPCMBuffer,
      prompt: String,
      options: CactusLanguageModel.Transcription.Options? = nil,
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> CactusLanguageModel.Transcription {
      try await self.transcribe(
        buffer: try buffer.cactusPCMBytes(),
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }

    /// Transcribes the specified PCM buffer.
    ///
    /// The buffer is converted to cactus-compatible mono 16 kHz PCM bytes using the default audio format conversion.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to transcribe.
    ///   - prompt: The prompt to use for transcription.
    ///   - options: The ``CactusLanguageModel/Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusLanguageModel/Transcription``.
    public func transcribe(
      buffer: sending AVAudioPCMBuffer,
      prompt: String,
      options: CactusLanguageModel.Transcription.Options? = nil,
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String, UInt32) -> Void
    ) async throws -> CactusLanguageModel.Transcription {
      try await self.transcribe(
        buffer: try buffer.cactusPCMBytes(),
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }

    /// Runs voice activity detection on the specified PCM buffer.
    ///
    /// The buffer is converted to cactus-compatible mono 16 kHz PCM bytes using the default audio format conversion.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusLanguageModel/VADOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``CactusLanguageModel/VADResult``.
    public func vad(
      buffer: sending AVAudioPCMBuffer,
      options: CactusLanguageModel.VADOptions? = nil,
      maxBufferSize: Int? = nil
    ) async throws -> CactusLanguageModel.VADResult {
      try await self.vad(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }
  }
#endif
