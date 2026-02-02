#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusTranscriptionStream {
    /// Processes an `AVAudioPCMBuffer` and returns interim transcription result.
    @discardableResult
    public func process(
      buffer: AVAudioPCMBuffer
    ) async throws -> CactusStreamTranscriber.ProcessedTranscription {
      let bytes = try buffer.cactusPCMBytes()
      return try await self.process(buffer: bytes)
    }
  }
#endif
