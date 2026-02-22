import Cactus
import CustomDump
import Testing

@Suite
struct `CactusVAD tests` {
  @Test(arguments: [
    VADSegmentDurationCase(
      startFrame: cactusAudioSampleRateHz,
      endFrame: cactusAudioSampleRateHz * 2,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: CactusDuration.seconds(1),
      expectedEnd: CactusDuration.seconds(2),
      expectedDuration: CactusDuration.seconds(1)
    ),
    VADSegmentDurationCase(
      startFrame: 8_000,
      endFrame: 16_000,
      samplingRate: 8_000,
      expectedStart: CactusDuration.seconds(1),
      expectedEnd: CactusDuration.seconds(2),
      expectedDuration: CactusDuration.seconds(1)
    ),
    VADSegmentDurationCase(
      startFrame: 400,
      endFrame: 800,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: CactusDuration.milliseconds(25),
      expectedEnd: CactusDuration.milliseconds(50),
      expectedDuration: CactusDuration.milliseconds(25)
    ),
    VADSegmentDurationCase(
      startFrame: 12_345,
      endFrame: 12_345,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: CactusDuration.nanoseconds(771_562_500),
      expectedEnd: CactusDuration.nanoseconds(771_562_500),
      expectedDuration: CactusDuration.nanoseconds(0)
    )
  ])
  func `Segment Duration Conversion`(testCase: VADSegmentDurationCase) {
    let segment = CactusVAD.Segment(
      startFrame: testCase.startFrame,
      endFrame: testCase.endFrame,
      samplingRate: testCase.samplingRate
    )

    expectNoDifference(segment.startDuration, testCase.expectedStart)
    expectNoDifference(segment.endDuration, testCase.expectedEnd)
    expectNoDifference(segment.duration, testCase.expectedDuration)
  }

  struct VADSegmentDurationCase: Sendable {
    let startFrame: Int
    let endFrame: Int
    let samplingRate: Int
    let expectedStart: CactusDuration
    let expectedEnd: CactusDuration
    let expectedDuration: CactusDuration
  }
}
