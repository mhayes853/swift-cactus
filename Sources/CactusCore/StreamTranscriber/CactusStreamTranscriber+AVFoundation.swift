#if canImport(AVFoundation)
  import AVFoundation

  extension CactusStreamTranscriber {
    /// Inserts an `AVAudioPCMBuffer` into this transcriber.
    public func insert(buffer: AVAudioPCMBuffer) throws {
      try self.insert(buffer: buffer.whisperPCMBytes())
    }
  }
#endif
