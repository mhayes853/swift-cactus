import Cactus
import CustomDump
import Foundation
import Testing

@Suite
final class `FilesystemTranscriptStore tests` {
  private let store = FilesystemTranscriptStore(directoryBaseURL: temporaryModelDirectory())

  deinit {
    try? FileManager.default.removeItem(at: self.store.directoryBaseURL)
  }

  @Test
  func `Nil Transcript When None For Key`() async throws {
    let transcript = try await self.store.transcript(forKey: "blob")
    let hasTranscript = try await self.store.hasTranscript(forKey: "blob")
    expectNoDifference(transcript, nil)
    expectNoDifference(hasTranscript, false)
  }

  @Test
  func `Save and Retrieve Transcript`() async throws {
    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")

    let transcript = try await self.store.transcript(forKey: "blob")
    let hasTranscript = try await self.store.hasTranscript(forKey: "blob")
    expectNoDifference(transcript, CactusTranscript())
    expectNoDifference(hasTranscript, true)
  }

  @Test
  func `Save and Remove Transcript`() async throws {
    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")
    try await self.store.removeTranscript(forKey: "blob")

    let transcript = try await self.store.transcript(forKey: "blob")
    let hasTranscript = try await self.store.hasTranscript(forKey: "blob")
    expectNoDifference(transcript, nil)
    expectNoDifference(hasTranscript, false)
  }

  @Test
  func `Isolates Transcripts For Separate Keys`() async throws {
    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")

    var transcript = try await self.store.transcript(forKey: "blob2")
    var hasTranscript = try await self.store.hasTranscript(forKey: "blob2")
    expectNoDifference(transcript, nil)
    expectNoDifference(hasTranscript, false)

    let t2 = CactusTranscript(elements: [
      CactusTranscript.Element(
        id: CactusGenerationID(),
        message: .system("You are an assistant...")
      )
    ])
    try await self.store.save(transcript: t2, forKey: "blob2")

    transcript = try await self.store.transcript(forKey: "blob2")
    hasTranscript = try await self.store.hasTranscript(forKey: "blob2")
    expectNoDifference(transcript, t2)
    expectNoDifference(hasTranscript, true)

    transcript = try await self.store.transcript(forKey: "blob")
    hasTranscript = try await self.store.hasTranscript(forKey: "blob")
    expectNoDifference(transcript, CactusTranscript())
    expectNoDifference(hasTranscript, true)
  }

  @Test
  func `Does Not Throw When Removing Non-Existent Transcript`() async throws {
    await #expect(throws: Never.self) {
      try await self.store.removeTranscript(forKey: "blob2")
    }

    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")

    await #expect(throws: Never.self) {
      try await self.store.removeTranscript(forKey: "blob2")
    }
  }

  @Test
  func `Returns False When Removing Non-Existent Transcript`() async throws {
    let didRemove = try await self.store.removeTranscript(forKey: "blob2")
    expectNoDifference(didRemove, false)
  }

  @Test
  func `Returns True When Removing Existent Transcript`() async throws {
    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")
    let didRemove = try await self.store.removeTranscript(forKey: "blob")
    expectNoDifference(didRemove, true)
  }

  @Test
  func `Lazily Creates Directory`() async throws {
    expectNoDifference(
      FileManager.default.fileExists(atPath: self.store.directoryBaseURL.relativePath),
      false
    )

    try await self.store.save(transcript: CactusTranscript(), forKey: "blob")

    expectNoDifference(
      FileManager.default.fileExists(atPath: self.store.directoryBaseURL.relativePath),
      true
    )
  }
}
