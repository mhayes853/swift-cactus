import Cactus
import CustomDump
import Testing

@Suite
struct `CactusVAD tests` {
  @Test(arguments: [
    VADSegmentDurationCase(
      startSampleIndex: cactusAudioSampleRateHz,
      endSampleIndex: cactusAudioSampleRateHz * 2,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: Duration.seconds(1),
      expectedEnd: Duration.seconds(2),
      expectedDuration: Duration.seconds(1)
    ),
    VADSegmentDurationCase(
      startSampleIndex: 8_000,
      endSampleIndex: 16_000,
      samplingRate: 8_000,
      expectedStart: Duration.seconds(1),
      expectedEnd: Duration.seconds(2),
      expectedDuration: Duration.seconds(1)
    ),
    VADSegmentDurationCase(
      startSampleIndex: 400,
      endSampleIndex: 800,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: Duration.milliseconds(25),
      expectedEnd: Duration.milliseconds(50),
      expectedDuration: Duration.milliseconds(25)
    ),
    VADSegmentDurationCase(
      startSampleIndex: 12_345,
      endSampleIndex: 12_345,
      samplingRate: cactusAudioSampleRateHz,
      expectedStart: Duration.nanoseconds(771_562_500),
      expectedEnd: Duration.nanoseconds(771_562_500),
      expectedDuration: Duration.nanoseconds(0)
    )
  ])
  func `Segment Duration Conversion`(testCase: VADSegmentDurationCase) {
    let segment = CactusVAD.Segment(
      startSampleIndex: testCase.startSampleIndex,
      endSampleIndex: testCase.endSampleIndex,
      samplingRate: testCase.samplingRate
    )

    expectNoDifference(segment.startDuration, testCase.expectedStart)
    expectNoDifference(segment.endDuration, testCase.expectedEnd)
    expectNoDifference(segment.duration, testCase.expectedDuration)
  }

  struct VADSegmentDurationCase: Sendable {
    let startSampleIndex: Int
    let endSampleIndex: Int
    let samplingRate: Int
    let expectedStart: Duration
    let expectedEnd: Duration
    let expectedDuration: Duration
  }
}
