import Cactus
import CustomDump
import Foundation
import IssueReporting
import SnapshotTesting
import Testing

@Suite
struct `CactusSTTSession tests` {
  @Test
  func `File Transcription Snapshot`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let session = try CactusSTTSession(from: modelURL)
    let request = CactusTranscription.Request(prompt: audioPrompt, content: .audio(testAudioURL))

    let transcription = try await session.transcribe(request: request)

    withKnownIssue {
      assertSnapshot(
        of: TranscriptionSnapshot(transcription: transcription),
        as: .json,
        record: true
      )
    }
  }

  @Test
  func `File Stream Snapshot`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let session = try CactusSTTSession(from: modelURL)
    let request = CactusTranscription.Request(prompt: audioPrompt, content: .audio(testAudioURL))

    let stream = try session.transcriptionStream(request: request)

    var streamedText = ""
    for try await token in stream.tokens {
      streamedText += token.stringValue
    }
    let transcription = try await stream.collectResponse()

    withKnownIssue {
      assertSnapshot(
        of: StreamTranscriptionSnapshot(
          streamedText: streamedText,
          transcription: transcription
        ),
        as: .json,
        record: true
      )
    }
  }

  @Test
  func `PCM Buffer Transcription Snapshot`() async throws {
    #if canImport(AVFoundation)
      let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
      let session = try CactusSTTSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusTranscription.Request.Content.pcm(pcmBuffer)
      let request = CactusTranscription.Request(
        prompt: audioPrompt,
        content: content
      )

      let transcription = try await session.transcribe(request: request)

      withKnownIssue {
        assertSnapshot(
          of: TranscriptionSnapshot(transcription: transcription),
          as: .json,
          record: true
        )
      }
    #endif
  }

  @Test
  func `File Transcription With Timestamps Snapshot`() async throws {
    #if canImport(AVFoundation)
      let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
      let session = try CactusSTTSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusTranscription.Request.Content.pcm(pcmBuffer)
      let request = CactusTranscription.Request(
        language: .english,
        includeTimestamps: true,
        content: content
      )

      let transcription = try await session.transcribe(request: request)

      withKnownIssue {
        assertSnapshot(
          of: TranscriptionSnapshot(transcription: transcription),
          as: .json,
          record: true
        )
      }
    #endif
  }

  @Test
  func `Stop Mid Stream Cancels And Calls Through To Model Stop`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let session = try CactusSTTSession(from: modelURL)
    let request = CactusTranscription.Request(
      prompt: audioPrompt,
      content: .pcm(longSilencePCMBytes)
    )

    let stream = try session.transcriptionStream(request: request)

    let responseTask = Task {
      try await stream.collectResponse()
    }

    try await Task.sleep(for: .milliseconds(50))
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await responseTask.value
    }
  }

  @Test
  func `Canceling Transcribe Cancels Stream And Ends Session`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let session = try CactusSTTSession(from: modelURL)
    let request = CactusTranscription.Request(
      prompt: audioPrompt,
      content: .pcm(longSilencePCMBytes)
    )

    let transcriptionTask = Task {
      try await session.transcribe(request: request)
    }

    try await Task.sleep(for: .milliseconds(50))
    transcriptionTask.cancel()

    await #expect(throws: CancellationError.self) {
      try await transcriptionTask.value
    }
  }

  @Test
  func `Custom Executor Transcription Succeeds`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let model = try CactusModelActor(
      executor: DispatchQueueSerialExecutor(),
      from: modelURL
    )
    let session = CactusSTTSession(model: model)
    let request = CactusTranscription.Request(prompt: audioPrompt, content: .audio(testAudioURL))

    await #expect(throws: Never.self) {
      try await session.transcribe(request: request)
    }
  }

  #if canImport(AVFoundation)
    @Test
    func `Moonshine Buffer Transcription Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .moonshineBase())
      let session = try CactusSTTSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusTranscription.Request.Content.pcm(pcmBuffer)
      let request = CactusTranscription.Request(prompt: .default, content: content)

      let transcription = try await session.transcribe(request: request)

      withKnownIssue {
        assertSnapshot(
          of: TranscriptionSnapshot(transcription: transcription),
          as: .json,
          record: true
        )
      }
    }

    @Test
    func `Parakeet Buffer Transcription Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .parakeetCtc_1_1b())
      let session = try CactusSTTSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusTranscription.Request.Content.pcm(pcmBuffer)
      let request = CactusTranscription.Request(prompt: .default, content: content)

      let transcription = try await session.transcribe(request: request)

      withKnownIssue {
        assertSnapshot(
          of: TranscriptionSnapshot(transcription: transcription),
          as: .json,
          record: true
        )
      }
    }
  #endif
}

private struct TranscriptionSnapshot: Codable {
  let content: String

  init(transcription: CactusTranscription) {
    switch transcription.content {
    case .fullTranscript(let text):
      self.content = text
    case .timestamps(let timestamps):
      self.content =
        timestamps
        .map { "\($0.startDuration.secondsDouble):\($0.transcript)" }
        .joined(separator: "\n")
    }
  }
}

private struct StreamTranscriptionSnapshot: Codable {
  let streamedText: String
  let parsedContent: String
  let prefillTokens: Int
  let decodeTokens: Int
  let totalTokens: Int
  let confidence: Double

  init(streamedText: String, transcription: CactusTranscription) {
    self.streamedText = streamedText
    self.parsedContent = TranscriptionSnapshot(transcription: transcription).content
    self.prefillTokens = transcription.metrics.prefillTokens
    self.decodeTokens = transcription.metrics.decodeTokens
    self.totalTokens = transcription.metrics.totalTokens
    self.confidence = transcription.metrics.confidence
  }
}

private let audioPrompt = CactusSTTPrompt.whisper(language: .english, includeTimestamps: false)
private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
private let missingAudioURL = FileManager.default.temporaryDirectory
  .appendingPathComponent("missing-audio-\(UUID().uuidString)")
private let longSilencePCMBytes = [UInt8](repeating: 0, count: 3_200_000)

private enum TranscriptionSessionTestError: Error {
  case timedOutWaitingForCancellation
}
