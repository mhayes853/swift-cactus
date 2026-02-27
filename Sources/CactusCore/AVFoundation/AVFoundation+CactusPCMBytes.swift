#if canImport(AVFoundation)
  @preconcurrency import AVFoundation

  extension AVAudioPCMBuffer {
    private enum PCMExportError: Error {
      case invalidBuffer
      case conversionFailed
      case missingData
    }

    /// Extracts cactus compatible PCM bytes from this buffer using the default audio format conversion.
    ///
    /// - Returns: Mono 16 kHz signed 16-bit PCM bytes.
    public func cactusPCMBytes() throws -> [UInt8] {
      guard self.frameLength > 0 else { return [] }

      let inputFormat = self.format
      let interleavedFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: cactusAudioSampleRate,
        channels: inputFormat.channelCount,
        interleaved: true
      )
      guard let interleavedFormat else { throw PCMExportError.invalidBuffer }

      let resampleRatio = interleavedFormat.sampleRate / inputFormat.sampleRate
      let estimatedFrames = Double(self.frameLength) * resampleRatio
      let outputFrameCapacity = AVAudioFrameCount(max(1, ceil(estimatedFrames)))

      guard let converter = AVAudioConverter(from: inputFormat, to: interleavedFormat),
        let outputBuffer = AVAudioPCMBuffer(
          pcmFormat: interleavedFormat,
          frameCapacity: outputFrameCapacity
        )
      else {
        throw PCMExportError.conversionFailed
      }

      var conversionError: NSError?
      let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
        outStatus.pointee = .haveData
        return self
      }

      switch status {
      case .haveData, .inputRanDry:
        break
      case .error, .endOfStream:
        if let conversionError {
          throw conversionError
        }
        throw PCMExportError.conversionFailed
      @unknown default:
        throw PCMExportError.conversionFailed
      }

      let audioBufferList = outputBuffer.audioBufferList.pointee
      let audioBuffer = audioBufferList.mBuffers
      guard let data = audioBuffer.mData else {
        throw PCMExportError.missingData
      }

      let channelCount = Int(outputBuffer.format.channelCount)
      let frameLength = Int(outputBuffer.frameLength)
      let sampleCount = frameLength * channelCount

      guard sampleCount > 0 else { return [] }

      let int16Samples = data.assumingMemoryBound(to: Int16.self)
      return self.downmixToMonoBytes(
        int16Samples: int16Samples,
        channelCount: channelCount,
        frameLength: frameLength
      )
    }

    private func downmixToMonoBytes(
      int16Samples: UnsafePointer<Int16>,
      channelCount: Int,
      frameLength: Int
    ) -> [UInt8] {
      var monoBytes = [UInt8](repeating: 0, count: frameLength * MemoryLayout<Int16>.stride)
      for frameIndex in 0..<frameLength {
        var sum = 0
        let baseIndex = frameIndex * channelCount
        for channelIndex in 0..<channelCount {
          sum += Int(int16Samples[baseIndex + channelIndex])
        }
        let sample = Int16(sum / channelCount)
        let littleEndianSample = UInt16(bitPattern: Int16(littleEndian: sample))
        let byteOffset = frameIndex * MemoryLayout<Int16>.stride
        monoBytes[byteOffset] = UInt8(littleEndianSample & 0xff)
        monoBytes[byteOffset + 1] = UInt8((littleEndianSample >> 8) & 0xff)
      }
      return monoBytes
    }
  }
#endif
