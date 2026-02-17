import Cactus
import CustomDump
import Foundation
import IssueReporting
import SnapshotTesting
import Testing

@Suite
struct `CactusTranscriptionSession tests` {
  @Test
  func `File Transcription Snapshot`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let session = try CactusTranscriptionSession(from: modelURL)
    let request = CactusTranscription.Request(prompt: audioPrompt, content: .audio(testAudioURL))

    let transcription = try await session.transcribe(
      request: request,
      options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
    )

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
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let session = try CactusTranscriptionSession(from: modelURL)
    let request = CactusTranscription.Request(prompt: audioPrompt, content: .audio(testAudioURL))

    let stream = try session.stream(
      request: request,
      options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
    )

    var streamedText = ""
    for try await token in stream.tokens {
      streamedText += token.stringValue
    }
    let response = try await stream.streamResponse()

    withKnownIssue {
      assertSnapshot(
        of: StreamTranscriptionSnapshot(
          streamedText: streamedText,
          transcription: response.output,
          metrics: response.metrics
        ),
        as: .json,
        record: true
      )
    }
  }

  @Test
  func `PCM Buffer Transcription Snapshot`() async throws {
    #if canImport(AVFoundation)
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let session = try CactusTranscriptionSession(from: modelURL)
      let pcmBuffer = try testAudioPCMBuffer()
      let content = try CactusTranscription.Request.Content.pcm(pcmBuffer)
      let request = CactusTranscription.Request(
        prompt: audioPrompt,
        content: content
      )

      let transcription = try await session.transcribe(
        request: request,
        options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
      )

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
  func `Duplicate Transcriptions Throw Already Transcribing`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let session = try CactusTranscriptionSession(from: modelURL)
    let request = CactusTranscription.Request(
      prompt: audioPrompt,
      content: .audio(missingAudioURL)
    )

    let stream = try session.stream(
      request: request,
      options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
    )

    #expect(throws: CactusTranscriptionStreamError.alreadyTranscribing) {
      try session.stream(
        request: request,
        options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
      )
    }

    await #expect(throws: CactusLanguageModel.TranscriptionError.self) {
      _ = try await stream.collectResponse()
    }
  }

  @Test
  func `Stop Mid Stream Cancels And Calls Through To Model Stop`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let session = try CactusTranscriptionSession(from: modelURL)
    let request = CactusTranscription.Request(
      prompt: audioPrompt,
      content: .pcm(longSilencePCMBytes)
    )

    let stream = try session.stream(
      request: request,
      options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
    )

    let responseTask = Task {
      try await stream.collectResponse()
    }

    try await Task.sleep(for: .milliseconds(50))
    stream.stop()

    await #expect(throws: CancellationError.self) {
      _ = try await responseTask.value
    }

    try await Task.sleep(for: .milliseconds(50))
    expectNoDifference(session.isTranscribing, false)
  }

  @Test
  func `Canceling Transcribe Cancels Stream And Ends Session`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
    let session = try CactusTranscriptionSession(from: modelURL)
    let request = CactusTranscription.Request(
      prompt: audioPrompt,
      content: .pcm(longSilencePCMBytes)
    )

    let transcriptionTask = Task {
      try await session.transcribe(
        request: request,
        options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
      )
    }

    try await Task.sleep(for: .milliseconds(50))
    transcriptionTask.cancel()

    await #expect(throws: CancellationError.self) {
      try await transcriptionTask.value
    }

    try await Task.sleep(for: .milliseconds(50))
    expectNoDifference(session.isTranscribing, false)
  }

  #if canImport(Observation)
    @Test
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func `isTranscribing Emits Observation Updates`() async throws {
      let modelURL = try await CactusLanguageModel.testAudioModelURL(request: .whisperSmall())
      let session = try CactusTranscriptionSession(from: modelURL)
      let request = CactusTranscription.Request(
        prompt: audioPrompt,
        content: .audio(missingAudioURL)
      )

      let values = Lock([Bool]())
      let token = observe {
        values.withLock { $0.append(session.isTranscribing) }
      }

      let stream = try session.stream(
        request: request,
        options: CactusLanguageModel.InferenceOptions(modelType: .whisper)
      )
      await #expect(throws: CactusLanguageModel.TranscriptionError.self) {
        _ = try await stream.collectResponse()
      }
      token.cancel()

      values.withLock { snapshots in
        expectNoDifference(snapshots, [false, true, false])
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
        .map { "\($0.seconds):\($0.transcript)" }
        .joined(separator: "\n")
    }
  }
}

private struct StreamTranscriptionSnapshot: Codable {
  let streamedText: String
  let parsedContent: String
  let metrics: CactusMessageMetric

  init(streamedText: String, transcription: CactusTranscription, metrics: CactusMessageMetric) {
    self.streamedText = streamedText
    self.parsedContent = TranscriptionSnapshot(transcription: transcription).content
    self.metrics = metrics
  }
}

private let audioPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!
private let missingAudioURL = FileManager.default.temporaryDirectory
  .appendingPathComponent("missing-audio-\(UUID().uuidString)")
private let longSilencePCMBytes = [UInt8](repeating: 0, count: 3_200_000)

private enum TranscriptionSessionTestError: Error {
  case timedOutWaitingForCancellation
}
