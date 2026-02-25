#if canImport(AVFoundation)
  import AVFoundation

  extension CactusVAD.Request.Content {
    /// Creates PCM VAD content from an `AVAudioPCMBuffer` to mono 16 kHz signed 16-bit PCM bytes.
    ///
    /// - Parameter buffer: The audio PCM buffer to convert.
    /// - Returns: Content configured for PCM-based VAD.
    public static func pcm(_ buffer: AVAudioPCMBuffer) throws -> Self {
      try .pcm(buffer.cactusPCMBytes())
    }
  }
#endif
