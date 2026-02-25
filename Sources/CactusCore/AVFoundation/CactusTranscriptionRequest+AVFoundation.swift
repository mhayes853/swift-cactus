#if canImport(AVFoundation)
  import AVFoundation

  extension CactusTranscription.Request.Content {
    private enum AVAudioBufferConversionError: Error {
      case unsupportedBufferType
    }

    /// Creates PCM transcription content from an `AVAudioPCMBuffer` to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameter buffer: The audio PCM buffer to convert.
    /// - Returns: Content configured for PCM-based transcription.
    public static func pcm(_ buffer: AVAudioPCMBuffer) throws -> Self {
      try .pcm(buffer.cactusPCMBytes())
    }
  }
#endif
