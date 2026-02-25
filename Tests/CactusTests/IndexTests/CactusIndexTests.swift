import CXXCactusShims
import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

@Suite
final class `CactusIndex tests` {
  private let directoryURL: URL
  private let embeddingDimensions = 8

  init() {
    self.directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("cactus-index-\(UUID())")
    try? FileManager.default.createDirectory(
      at: self.directoryURL,
      withIntermediateDirectories: true
    )
  }

  deinit {
    try? FileManager.default.removeItem(at: self.directoryURL)
  }

  @Test
  func `Query Empty Index Returns No Results`() throws {
    let index = try self.makeIndex()

    let results = try index.query(self.makeQuery(seed: 1))
    expectNoDifference(results.isEmpty, true)
  }

  @Test
  func `Add Document Then Query By Id Returns Document`() throws {
    let index = try self.makeIndex()
    let document = self.makeDocument(id: 1, content: "hello")

    try index.add(document: document)
    let retrieved = try index.document(withId: document.id)

    self.expectDocumentEqual(retrieved, document)
  }

  @Test
  func `Add Document Then Delete Then Query By Id Throws Error`() throws {
    let index = try self.makeIndex()
    let document = self.makeDocument(id: 2, content: "goodbye")

    try index.add(document: document)
    try index.deleteDocument(withId: document.id)
    #expect(throws: CactusIndexError.self) {
      try index.document(withId: document.id)
    }
  }

  @Test
  func `Add Document Then Overwrite With Duplicate Id Throws Error`() throws {
    let index = try self.makeIndex()
    let original = self.makeDocument(id: 3, content: "original")
    let updated = self.makeDocument(id: 3, content: "updated", seed: 4)

    try index.add(document: original)
    #expect(throws: CactusIndexError.self) {
      try index.add(document: updated)
    }
  }

  @Test
  func `Deleting Missing Document Throws Error`() throws {
    let index = try self.makeIndex()

    #expect(throws: CactusIndexError.self) {
      try index.deleteDocument(withId: 404)
    }
  }

  @Test
  func `Query Missing Document Throws Error`() throws {
    let index = try self.makeIndex()

    #expect(throws: CactusIndexError.self) {
      try index.document(withId: 999)
    }
  }

  @Test
  func `Creating Index With Negative Embedding Dimensions Throws Error`() throws {
    #expect(throws: CactusIndexError.self) {
      try CactusIndex(directory: self.directoryURL, embeddingDimensions: -1)
    }
  }

  @Test
  func `Query Documents Snapshot Dump`() throws {
    let index = try self.makeIndex()
    let documents = [
      self.makeDocument(id: 1, content: "alpha", seed: 10),
      self.makeDocument(id: 2, content: "beta", seed: 9),
      self.makeDocument(id: 3, content: "gamma", seed: 8)
    ]

    try index.add(documents: documents)
    let results = try index.query(self.makeQuery(seed: 11))

    assertSnapshot(of: results, as: .dump)
  }

  @Test
  func `Query Multiple Documents Snapshot Dump`() throws {
    let index = try self.makeIndex()
    let documents = [
      self.makeDocument(id: 4, content: "delta", seed: 10),
      self.makeDocument(id: 5, content: "epsilon", seed: 9),
      self.makeDocument(id: 6, content: "zeta", seed: 8)
    ]

    try index.add(documents: documents)
    let queries = [
      self.makeQuery(seed: 21),
      self.makeQuery(seed: 22),
      self.makeQuery(seed: 23)
    ]
    let results = try index.query(queries)

    assertSnapshot(of: results, as: .dump)
  }

  @Test
  func `Bulk Query Returns Documents In Requested Order`() throws {
    let index = try self.makeIndex()
    let first = self.makeDocument(id: 101, content: "one")
    let second = self.makeDocument(id: 102, content: "two")
    let third = self.makeDocument(id: 103, content: "three")

    try index.add(documents: [first, second, third])
    let retrieved = try index.documents(withIds: [third.id, first.id, second.id])

    self.expectDocumentEqual(retrieved[0], third)
    self.expectDocumentEqual(retrieved[1], first)
    self.expectDocumentEqual(retrieved[2], second)
  }

  @Test
  func `Bulk Query With Duplicate Ids Throws Error`() throws {
    let index = try self.makeIndex()
    let document = self.makeDocument(id: 200, content: "dup")

    try index.add(document: document)

    #expect(throws: CactusIndexError.self) {
      try index.documents(withIds: [document.id, document.id])
    }
  }

  @Test
  func `Insert Large Document Then Retrieve By Id`() throws {
    let index = try self.makeIndex()
    let content = String(repeating: "a", count: 4097)
    let document = self.makeDocument(id: 300, content: content)
    let bufferSizes = CactusIndex.Document.BufferSizes(content: 4096, metadata: 16)

    try index.add(document: document)
    #expect(throws: CactusIndexError.self) {
      try index.document(withId: document.id, bufferSizes: bufferSizes)
    }
  }

  @Test
  func `Bulk Query For Non-Existent Document Throws Error`() throws {
    let index = try self.makeIndex()
    #expect(throws: CactusIndexError.self) {
      try index.documents(withIds: [1])
    }
  }

  private func makeIndex() throws -> CactusIndex {
    try CactusIndex(directory: self.directoryURL, embeddingDimensions: self.embeddingDimensions)
  }

  private func makeDocument(
    id: Int32,
    content: String,
    metadata: String = "",
    seed: UInt64? = nil
  ) -> CactusIndex.Document {
    CactusIndex.Document(
      id: id,
      embedding: self.makeEmbedding(seed: seed ?? UInt64(id)),
      metadata: metadata,
      content: content
    )
  }

  private func makeQuery(seed: UInt64) -> CactusIndex.Query {
    CactusIndex.Query(embeddings: self.makeEmbedding(seed: seed))
  }

  private func makeEmbedding(seed: UInt64) -> [Float] {
    var generator = SeededRandomNumberGenerator(seed: seed)
    return (0..<self.embeddingDimensions)
      .map { _ in Float.random(in: -1...1, using: &generator) }
  }

  private func expectDocumentEqual(
    _ lhs: CactusIndex.Document?,
    _ rhs: CactusIndex.Document?
  ) {
    expectNoDifference(lhs?.id, rhs?.id)
    expectNoDifference(lhs?.content, rhs?.content)
    expectNoDifference(lhs?.metadata, rhs?.metadata)
  }
}
