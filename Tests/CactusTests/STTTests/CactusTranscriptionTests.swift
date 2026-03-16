import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusTranscription tests` {
  @Test
  @available(*, deprecated)
  func `Deprecated Content Returns Full Transcript When Segments Empty`() {
    let transcription = CactusTranscription(
      id: CactusGenerationID(),
      metrics: .init(
        prefillTokens: 0,
        decodeTokens: 0,
        totalTokens: 0,
        confidence: 1,
        prefillTps: 0,
        decodeTps: 0,
        ramUsageMb: 0,
        didHandoffToCloud: false,
        durationToFirstToken: .zero,
        totalDuration: .zero
      ),
      transcript: "Hello world",
      segments: [CactusTranscription.Segment]()
    )

    expectNoDifference(transcription.content, .fullTranscript("Hello world"))
  }

  @Test
  @available(*, deprecated)
  func `Deprecated Content Returns Timestamps When Segments Present`() {
    let transcription = CactusTranscription(
      id: CactusGenerationID(),
      metrics: .init(
        prefillTokens: 0,
        decodeTokens: 0,
        totalTokens: 0,
        confidence: 1,
        prefillTps: 0,
        decodeTps: 0,
        ramUsageMb: 0,
        didHandoffToCloud: false,
        durationToFirstToken: .zero,
        totalDuration: .zero
      ),
      transcript: "Hello world",
      segments: [
        CactusTranscription.Segment(
          startDuration: .seconds(0),
          endDuration: .seconds(1),
          transcript: "Hello"
        )
      ]
    )

    expectNoDifference(
      transcription.content,
      .timestamps([
        CactusTranscription.Timestamp(startDuration: .seconds(0), transcript: "Hello")
      ])
    )
  }

  @Test
  @available(*, deprecated)
  func `Deprecated Content Response From Timestamps`() {
    let content = CactusTranscription.Content.timestamps([
      CactusTranscription.Timestamp(startDuration: .seconds(0), transcript: "Hello"),
      CactusTranscription.Timestamp(startDuration: .seconds(1.5), transcript: "World")
    ])

    expectNoDifference(content.response, "<|0.00|>Hello<|1.50|>World")
  }

  @Test
  @available(*, deprecated)
  func `Deprecated Content Response Parser Still Supports Whisper Style Strings`() {
    let content = CactusTranscription.Content(
      response: "<|0.00|>Hello<|1.50|>World"
    )

    expectNoDifference(
      content,
      .timestamps([
        CactusTranscription.Timestamp(startDuration: .seconds(0), transcript: "Hello"),
        CactusTranscription.Timestamp(startDuration: .seconds(1.5), transcript: "World")
      ])
    )
  }
}
