import Cactus
import CustomDump
import Testing

@Suite
struct `CactusUserMessage tests` {
  @Test
  func `Options Init Request Maps Cloud Handoff Values`() throws {
    let cloudHandoff = CactusUserMessage.CloudHandoff(
      handoffWithImages: false,
      cloudHandoffThreshold: 0.42,
      cloudTimeoutDuration: Duration.seconds(9)
    )
    let request = CactusUserMessage(
      maxTokens: 256,
      temperature: 0.2,
      topP: 0.5,
      topK: 12,
      stopSequences: ["stop"],
      forceFunctions: true,
      toolRagTopK: 4,
      includeStopSequences: true,
      isTelemetryEnabled: true,
      maxBufferSize: 1024,
      cloudHandoff: cloudHandoff
    ) {
      "Hello"
    }

    let options = CactusModel.Completion.Options(message: request)

    let expectedOptions = CactusModel.Completion.Options(
      maxTokens: 256,
      temperature: 0.2,
      topP: 0.5,
      topK: 12,
      stopSequences: ["stop"],
      forceFunctions: true,
      cloudHandoffThreshold: 0.42,
      toolRagTopK: 4,
      includeStopSequences: true,
      isTelemetryEnabled: true,
      autoHandoff: true,
      cloudTimeoutDuration: Duration.seconds(9),
      handoffWithImages: false
    )
    expectNoDifference(options, expectedOptions)
  }
}
