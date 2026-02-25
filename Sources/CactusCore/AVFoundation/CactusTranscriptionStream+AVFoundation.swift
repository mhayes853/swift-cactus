#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusTranscriptionStream {
    /// Processes an `AVAudioPCMBuffer` and returns interim transcription result.
    ///
    /// The buffer is converted to cactus-compatible mono 16 kHz PCM bytes using the default audio format conversion.
    @discardableResult
    public func process(
      buffer: AVAudioPCMBuffer
    ) async throws -> CactusStreamTranscriber.ProcessedTranscription {
      let bytes = try buffer.cactusPCMBytes()
      return try await self.process(buffer: bytes)
    }
  }
#endif
