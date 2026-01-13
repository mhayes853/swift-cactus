#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusTranscriptionStream {
    /// Inserts an `AVAudioPCMBuffer` into the stream.
    @discardableResult
    public func insert(
      buffer: AVAudioPCMBuffer
    ) async throws -> CactusStreamTranscriber.ProcessedTranscription {
      try await self.insert(buffer: buffer.whisperPCMBytes())
    }
  }
#endif
