import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

@Suite("CactusLanguageModel tests")
struct CactusLanguageModelTests {
  @Test("Attempt To Create Model From Non-Existent URL, Throws Error")
  func attemptToCreateModelFromNonExistentURLThrowsError() async throws {
    let error = #expect(throws: CactusLanguageModel.ModelCreationError.self) {
      try CactusLanguageModel(from: temporaryDirectory())
    }
    expectNoDifference(error?.message.starts(with: "Failed to create model from:"), true)
  }

  @Test("Successfully Creates Model From Downloaded Model")
  func successfullyCreatesModelFromDownloadedModel() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    #expect(throws: Never.self) {
      try CactusLanguageModel(from: modelURL)
    }
  }

  @Test("Generates Embeddings")
  func generatesEmbeddings() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.embeddings(for: "This is some text.")
    assertSnapshot(of: embeddings, as: .dump)
  }

  @Test("Throws Buffer Too Small Error When Buffer Size Too Small")
  func throwsBufferTooSmallErrorWhenBufferSizeTooSmall() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 20)
    }
  }

  @Test("Throws Buffer Too Small Error When Buffer Size Zero")
  func throwsBufferTooSmallErrorWhenBufferSizeZero() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 0)
    }
  }

  @Test(
    "Schema Value JSON",
    arguments: [
      (CactusLanguageModel.SchemaValue.number(1), "1"),
      (.string("blob"), "\"blob\""),
      (.boolean(true), "true"),
      (.null, "null"),
      (.array([.string("blob"), .number(1)]), "[\"blob\",1]"),
      (.array([]), "[]"),
      (.object([:]), "{}"),
      (.object(["key": .string("value")]), "{\"key\":\"value\"}")
    ]
  )
  func schemaValueJSON(value: CactusLanguageModel.SchemaValue, json: String) throws {
    let data = try JSONEncoder().encode(value)
    expectNoDifference(String(decoding: data, as: UTF8.self), json)

    let decodedValue = try JSONDecoder().decode(CactusLanguageModel.SchemaValue.self, from: data)
    expectNoDifference(value, decodedValue)
  }
}
