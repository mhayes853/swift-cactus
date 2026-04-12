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
      options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> CactusModel.Transcription {
      try Task.checkCancellation()
      return try await self.transcribe(
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
      options: CactusModel.Transcription.Options = CactusModel.Transcription.Options(),
      transcriptionMaxBufferSize: Int? = nil,
      onToken: @escaping @Sendable (String, UInt32) -> Void
    ) async throws -> CactusModel.Transcription {
      try Task.checkCancellation()
      return try await self.transcribe(
        buffer: try buffer.cactusPCMBytes(),
        prompt: prompt,
        options: options,
        transcriptionMaxBufferSize: transcriptionMaxBufferSize,
        onToken: onToken
      )
    }

    /// Detects language from the specified PCM buffer converted to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/LanguageDetectionOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``CactusModel/LanguageDetection``.
    public func detectLanguage(
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.LanguageDetectionOptions? = nil,
      maxBufferSize: Int? = nil
    ) async throws -> CactusModel.LanguageDetection {
      try Task.checkCancellation()
      return try await self.detectLanguage(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
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
      try Task.checkCancellation()
      return try await self.vad(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Generates a completed chat turn with reusable continuation messages using the specified audio buffer.
    ///
    /// - Parameters:
    ///   - messages: The list of ``CactusModel/Message`` instances.
    ///   - buffer: The PCM buffer to include with the messages.
    ///   - options: The ``CactusModel/Completion/Options``.
    ///   - maxBufferSize: The maximum buffer size to store the completion.
    ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusModel/CompletedChatTurn``.
    public func complete(
      messages: [CactusModel.Message],
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
      maxBufferSize: Int? = nil,
      functions: [CactusModel.FunctionDefinition] = [],
      onToken: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> CactusModel.CompletedChatTurn {
      try await self.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: try buffer.cactusPCMBytes(),
        onToken: onToken
      )
    }

    /// Generates a completed chat turn with reusable continuation messages using the specified audio buffer.
    ///
    /// - Parameters:
    ///   - messages: The list of ``CactusModel/Message`` instances.
    ///   - buffer: The PCM buffer to include with the messages.
    ///   - options: The ``CactusModel/Completion/Options``.
    ///   - maxBufferSize: The maximum buffer size to store the completion.
    ///   - functions: A list of ``CactusModel/FunctionDefinition`` instances.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CactusModel/CompletedChatTurn``.
    public func complete(
      messages: [CactusModel.Message],
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
      maxBufferSize: Int? = nil,
      functions: [CactusModel.FunctionDefinition] = [],
      onToken: @escaping @Sendable (String, UInt32) -> Void
    ) async throws -> CactusModel.CompletedChatTurn {
      try await self.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: try buffer.cactusPCMBytes(),
        onToken: onToken
      )
    }

    /// Runs speaker diarization on the specified PCM buffer.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/DiarizationOptions``.
    ///   - maxBufferSize: The maximum buffer size for the response.
    /// - Returns: A ``CactusModel/DiarizationResult``.
    public func diarize(
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.DiarizationOptions? = nil,
      maxBufferSize: Int? = nil
    ) async throws -> CactusModel.DiarizationResult {
      try Task.checkCancellation()
      return try await self.diarize(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Extracts speaker embeddings from the specified PCM buffer.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/SpeakerEmbeddingsOptions``.
    ///   - maxBufferSize: The maximum buffer size for the response.
    /// - Returns: A speaker embedding vector.
    public func speakerEmbeddings(
      buffer: sending AVAudioPCMBuffer,
      options: CactusModel.SpeakerEmbeddingsOptions? = nil,
      maxBufferSize: Int? = nil
    ) async throws -> [Float] {
      try Task.checkCancellation()
      return try await self.speakerEmbeddings(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }
  }
#endif
