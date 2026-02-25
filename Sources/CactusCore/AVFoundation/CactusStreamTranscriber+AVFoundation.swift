#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusStreamTranscriber {
    /// Processes an `AVAudioPCMBuffer` and returns interim transcription result.
    ///
    /// The buffer is converted to cactus-compatible mono 16 kHz PCM bytes using the default audio format conversion.
    @discardableResult
    public func process(buffer: AVAudioPCMBuffer) throws -> ProcessedTranscription {
      let bytes = try buffer.cactusPCMBytes()
      return try bytes.withUnsafeBufferPointer { try self.process(buffer: $0) }
    }
  }
#endif
