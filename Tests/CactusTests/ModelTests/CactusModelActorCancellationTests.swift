import Cactus
import Foundation
import Testing

@Suite
struct `CactusModelActor cancellation tests` {
  @Test
  func `Canceling Complete Stops Generation And Throws Cancellation Error`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let actor = try CactusModelActor(from: modelURL)

    let task = Task {
      try await actor.complete(
        messages: [
          .system("You are a verbose assistant that writes long responses."),
          .user("Write a detailed tutorial about Swift concurrency with examples.")
        ]
      )
    }

    try await Task.sleep(for: .milliseconds(50))
    task.cancel()

    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }

  @Test
  func `Canceling Transcribe Stops Generation And Throws Cancellation Error`() async throws {
    let modelURL = try await CactusModel.testModelURL(request: .whisperSmall())
    let actor = try CactusModelActor(from: modelURL)

    let task = Task {
      try await actor.transcribe(
        buffer: longSilencePCMBytes,
        prompt: whisperPrompt
      )
    }

    try await Task.sleep(for: .milliseconds(50))
    task.cancel()

    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }
}

private let whisperPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
private let longSilencePCMBytes = [UInt8](repeating: 0, count: 3_200_000)
