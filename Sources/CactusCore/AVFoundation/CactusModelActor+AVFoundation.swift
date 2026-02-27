#if canImport(AVFoundation)
  import AVFoundation

  // MARK: - CactusModelActor + AVFoundation

  extension CactusModelActor {
    /// Transcribes the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to transcribe.
    ///   - prompt: The prompt to use for transcription.
    ///   - options: The ``CactusModel/Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusModel/Transcription``.
    public func transcribe(
      buffer: sending AVAudioPCMBuffer,
      prompt: String,
      options: CactusModel.Transcription.Options? = nil,
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> CactusModel.Transcription {
      try await self.transcribe(
        buffer: try buffer.cactusPCMBytes(),
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }

    /// Transcribes the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to transcribe.
    ///   - prompt: The prompt to use for transcription.
    ///   - options: The ``CactusModel/Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusModel/Transcription``.
    public func transcribe(
      buffer: sending AVAudioPCMBuffer,
      prompt: String,
      options: CactusModel.Transcription.Options? = nil,
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String, UInt32) -> Void
    ) async throws -> CactusModel.Transcription {
      try await self.transcribe(
        buffer: try buffer.cactusPCMBytes(),
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }

    /// Runs voice activity detection on the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/VADOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``CactusModel/VADResult``.
    public func vad(
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.VADOptions? = nil,
      maxBufferSize: Int? = nil
    ) async throws -> CactusModel.VADResult {
      try await self.vad(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }
  }
#endif
