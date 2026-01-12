#if canImport(AVFoundation)
  import Foundation
  import AVFoundation

  extension CactusTranscriptionStream {
    /// Inserts an `AVAudioPCMBuffer` into the stream.
    public func insert(buffer: AVAudioPCMBuffer) async throws {
      try await self.insert(buffer: buffer.whisperPCMBytes())
    }
  }
#endif
