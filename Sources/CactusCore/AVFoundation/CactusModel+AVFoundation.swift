#if canImport(AVFoundation)
  import AVFoundation

  extension CactusModel {
    /// Transcribes the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to transcribe.
    ///   - prompt: The prompt to use for transcription.
    ///   - options: The ``Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``Transcription``.
    public func transcribe(
      buffer: AVAudioPCMBuffer,
      prompt: String,
      options: Transcription.Options = Transcription.Options(),
      transcriptionMaxBufferSize: Int? = nil,
      onToken: (String) -> Void = { _ in }
    ) throws -> Transcription {
      try self.transcribe(
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
    ///   - options: The ``Transcription/Options``.
    ///   - transcriptionMaxBufferSize: The maximum buffer size to store the transcription.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``Transcription``.
    public func transcribe(
      buffer: AVAudioPCMBuffer,
      prompt: String,
      options: Transcription.Options = Transcription.Options(),
      transcriptionMaxBufferSize: Int? = nil,
      onToken: (String, UInt32) -> Void
    ) throws -> Transcription {
      try self.transcribe(
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
    ///   - options: The ``LanguageDetectionOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``LanguageDetection``.
    public func detectLanguage(
      buffer: AVAudioPCMBuffer,
      options: LanguageDetectionOptions? = nil,
      maxBufferSize: Int? = nil
    ) throws -> LanguageDetection {
      try self.detectLanguage(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Runs voice activity detection on the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``VADOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``VADResult``.
    public func vad(
      buffer: AVAudioPCMBuffer,
      options: VADOptions? = nil,
      maxBufferSize: Int? = nil
    ) throws -> VADResult {
      try self.vad(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Runs speaker diarization on the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/DiarizationOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A ``CactusModel/DiarizationResult``.
    public func diarize(
      buffer: AVAudioPCMBuffer,
      options: CactusModel.DiarizationOptions? = nil,
      maxBufferSize: Int? = nil
    ) throws -> CactusModel.DiarizationResult {
      try self.diarize(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Extracts speaker embeddings from the specified PCM buffer to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to analyze.
    ///   - options: The ``CactusModel/SpeakerEmbeddingsOptions``.
    ///   - maxBufferSize: The maximum buffer size to store the result.
    /// - Returns: A speaker embedding vector.
    public func speakerEmbeddings(
      buffer: AVAudioPCMBuffer,
      options: CactusModel.SpeakerEmbeddingsOptions? = nil,
      maxBufferSize: Int? = nil
    ) throws -> [Float] {
      try self.speakerEmbeddings(
        pcmBuffer: try buffer.cactusPCMBytes(),
        options: options,
        maxBufferSize: maxBufferSize
      )
    }

    /// Generates a completed chat turn with reusable continuation messages using the specified audio buffer.
    ///
    /// - Parameters:
    ///   - messages: The list of ``Message`` instances.
    ///   - buffer: The PCM buffer to include with the messages.
    ///   - options: The ``Completion/Options``.
    ///   - maxBufferSize: The maximum buffer size to store the completion.
    ///   - functions: A list of ``FunctionDefinition`` instances.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CompletedChatTurn``.
    public func complete(
      messages: [Message],
      buffer: AVAudioPCMBuffer,
      options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
      maxBufferSize: Int? = nil,
      functions: [CactusModel.FunctionDefinition] = [],
      onToken: @escaping (String) -> Void = { _ in }
    ) throws -> CactusModel.CompletedChatTurn {
      try self.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: try buffer.cactusPCMBytes()
      ) { token, _ in
        onToken(token)
      }
    }

    /// Generates a completed chat turn with reusable continuation messages using the specified audio buffer.
    ///
    /// - Parameters:
    ///   - messages: The list of ``Message`` instances.
    ///   - buffer: The PCM buffer to include with the messages.
    ///   - options: The ``Completion/Options``.
    ///   - maxBufferSize: The maximum buffer size to store the completion.
    ///   - functions: A list of ``FunctionDefinition`` instances.
    ///   - onToken: A callback invoked whenever a token is generated.
    /// - Returns: A ``CompletedChatTurn``.
    public func complete(
      messages: [Message],
      buffer: AVAudioPCMBuffer,
      options: CactusModel.Completion.Options = CactusModel.Completion.Options(),
      maxBufferSize: Int? = nil,
      functions: [CactusModel.FunctionDefinition] = [],
      onToken: @escaping (String, UInt32) -> Void
    ) throws -> CactusModel.CompletedChatTurn {
      try self.complete(
        messages: messages,
        options: options,
        maxBufferSize: maxBufferSize,
        functions: functions,
        pcmBuffer: try buffer.cactusPCMBytes(),
        onToken: onToken
      )
    }
  }
#endif
