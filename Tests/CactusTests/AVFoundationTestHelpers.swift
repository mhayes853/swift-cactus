#if canImport(AVFoundation)
  import AVFoundation
  import Testing

  func testAudioPCMBuffer(
    startFrame: AVAudioFramePosition = 0,
    frameLength: AVAudioFrameCount? = nil
  ) throws -> AVAudioPCMBuffer {
    let audioURL = try #require(Bundle.module.url(forResource: "test", withExtension: "wav"))
    let audioFile = try AVAudioFile(forReading: audioURL)
    audioFile.framePosition = startFrame
    let format = audioFile.processingFormat
    let remainingFrames = AVAudioFrameCount(audioFile.length - startFrame)
    let targetFrameLength = frameLength ?? remainingFrames
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: targetFrameLength))
    try audioFile.read(into: buffer, frameCount: targetFrameLength)
    return buffer
  }
#endif
