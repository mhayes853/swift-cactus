#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusStreamTranscriber {
    /// Processes an `AVAudioPCMBuffer` and returns interim transcription result to mono 16 kHz signed 16-bit PCM bytes.
    @discardableResult
    public func process(buffer: AVAudioPCMBuffer) throws -> ProcessedTranscription {
      let bytes = try buffer.cactusPCMBytes()
      return try bytes.withUnsafeBufferPointer { try self.process(buffer: $0) }
    }
  }
#endif
