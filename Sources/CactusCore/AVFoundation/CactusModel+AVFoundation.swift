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
  }
#endif
