#if canImport(AVFoundation)
  import AVFoundation

  extension CactusLanguageModel {
    /// Transcribes the specified PCM buffer.
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
      options: Transcription.Options? = nil,
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

    /// Transcribes the specified PCM buffer.
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
      options: Transcription.Options? = nil,
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
  }
#endif
