import CXXCactusShims
import Foundation

// MARK: - CactusIndex

/// An index for storing and querying document embeddings.
///
/// ```swift
/// import Cactus
///
/// let model = try CactusModel(from: modelURL)
/// let index = try CactusIndex(
///   directory: .applicationSupportDirectory.appending(path: "my-index"),
///   embeddingDimensions: 2048
/// )
///
/// let embeddings = try model.embeddings(for: "Some text")
///
/// let document = CactusIndex.Document(
///   id: 0,
///   embedding: embeddings,
///   content: "Some text"
/// )
/// try index.add(document: document)
///
/// let queryEmbeddings = try model.embeddings(for: "Another text")
/// let query = CactusIndex.Query(embeddings: queryEmbeddings)
/// let results = try index.query(query)
///
/// for result in results {
///   print(result.documentId, result.score)
/// }
/// ```
public struct CactusIndex: ~Copyable {
  /// The maximum buffer size for a document's content or metadata.
  public static let maxBufferSize = 65535

  /// The raw index pointer.
  private let indexPointer: cactus_index_t

  /// The dimensionality of the embeddings stored in this index.
  public let embeddingDimensions: Int

  /// Creates an index at the specified directory.
  ///
  /// - Parameters:
  ///   - directory: The directory where the index will be stored.
  ///   - embeddingDimensions: The dimensionality of the embeddings stored in the index.
  public init(directory: URL, embeddingDimensions: Int) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let index = cactus_index_init(directory.nativePath, embeddingDimensions)
    guard let index else { throw CactusIndexError.lastErrorMessage() }

    self.init(index: index, embeddingDimensions: embeddingDimensions)
  }

  /// Creates an index.
  ///
  /// - Parameters:
  ///   - index: The raw index pointer.
  ///   - embeddingDimensions: The dimensionality of the embeddings stored in the index.
  public init(
    index: consuming cactus_index_t,
    embeddingDimensions: Int
  ) {
    self.indexPointer = index
    self.embeddingDimensions = embeddingDimensions
  }

  deinit {
    cactus_index_destroy(self.indexPointer)
  }

  /// Provides scoped access to the underlying index pointer.
  ///
  /// - Parameter body: The operation to run with the index pointer.
  /// - Returns: The operation return value.
  public borrowing func withIndexPointer<Result: ~Copyable, E: Error>(
    _ body: (cactus_index_t) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    try body(self.indexPointer)
  }
}

// MARK: - Document

extension CactusIndex {
  /// A stored document in an index.
  public struct Document: Hashable, Sendable, Identifiable {
    public typealias ID = Int32

    /// The unique identifier of the document.
    public let id: ID

    /// The embedding of the document.
    public var embedding: [Float]

    /// An arbitrary string for metadata.
    public var metadata: String

    /// The content of the document.
    public var content: String

    /// Creates a document.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the document.
    ///   - embedding: The embedding of the document.
    ///   - metadata: An arbitrary string for metadata.
    ///   - content: The content of the document.
    public init(id: ID, embedding: [Float], metadata: String = "", content: String) {
      self.id = id
      self.embedding = embedding
      self.metadata = metadata
      self.content = content
    }
  }
}

extension CactusIndex.Document {
  /// The buffer sizes for retrieving documents.
  public struct BufferSizes: Hashable, Sendable {
    /// The buffer size for content.
    public var content: Int

    /// The buffer size for metadata.
    public var metadata: Int

    /// Creates buffer sizes.
    ///
    /// - Parameters:
    ///   - content: The buffer size for content.
    ///   - metadata: The buffer size for metadata.
    public init(content: Int, metadata: Int) {
      self.content = content
      self.metadata = metadata
    }
  }
}

extension CactusIndex {
  /// Attempts to retrieve the document with the specified id.
  ///
  /// - Parameters:
  ///   - id: The id of the document to retrieve.
  ///   - bufferSizes: The buffer sizes for retrieving the document.
  /// - Returns: A ``Document``.
  public func document(
    withId id: Document.ID,
    bufferSizes: Document.BufferSizes? = nil
  ) throws -> Document {
    try self.documents(withIds: [id], bufferSizes: bufferSizes.map { [$0] })[0]
  }

  /// Attempts to retrieve the document with the specified ids.
  ///
  /// - Parameters:
  ///   - ids: The ids of the documents to retrieve.
  ///   - bufferSizes: The buffer sizes for retrieving the documents.
  /// - Returns: An array of ``Document`` in the same order as the IDs.
  public func documents(
    withIds ids: [Document.ID],
    bufferSizes: [Document.BufferSizes]? = nil
  ) throws -> [Document] {
    guard !ids.isEmpty else { return [] }
    if let bufferSizes, bufferSizes.count != ids.count {
      throw CactusIndexError(message: "Buffer sizes must match the number of document IDs.")
    }
    var contentBufferSizes =
      (bufferSizes?.map(\.content)
      ?? Array(
        repeating: CactusIndex.maxBufferSize,
        count: ids.count
      ))
      .map { max(1, $0) }
    var metadataBufferSizes =
      (bufferSizes?.map(\.metadata)
      ?? Array(
        repeating: CactusIndex.maxBufferSize,
        count: ids.count
      ))
      .map { max(1, $0) }
    var embeddingBufferSizes = Array(repeating: max(1, self.embeddingDimensions), count: ids.count)

    var contentBuffers = contentBufferSizes.map { [CChar](repeating: 0, count: $0) }
    var metadataBuffers = metadataBufferSizes.map { [CChar](repeating: 0, count: $0) }
    var embeddingBuffers = embeddingBufferSizes.map { [Float](repeating: .zero, count: $0) }

    let result = ids.withUnsafeBufferPointer { idsPtr in
      self.withMutableBufferPointers(&contentBuffers) { contentPointers in
        self.withMutableBufferPointers(&metadataBuffers) { metadataPointers in
          self.withMutableBufferPointers(&embeddingBuffers) { embeddingPointers in
            return contentBufferSizes.withUnsafeMutableBufferPointer { contentSizePtr in
              metadataBufferSizes.withUnsafeMutableBufferPointer { metadataSizePtr in
                embeddingBufferSizes.withUnsafeMutableBufferPointer { embeddingSizePtr in
                  cactus_index_get(
                    self.indexPointer,
                    idsPtr.baseAddress,
                    ids.count,
                    contentPointers,
                    contentSizePtr.baseAddress,
                    metadataPointers,
                    metadataSizePtr.baseAddress,
                    embeddingPointers,
                    embeddingSizePtr.baseAddress
                  )
                }
              }
            }
          }
        }
      }
    }
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
    var documents = [Document]()
    documents.reserveCapacity(ids.count)
    for index in ids.indices {
      let embeddingCount = Self.embeddingElementCount(
        from: embeddingBufferSizes[index],
        embeddingDimensions: self.embeddingDimensions
      )
      documents.append(
        Document(
          id: ids[index],
          embedding: Array(embeddingBuffers[index].prefix(embeddingCount)),
          metadata: Self.stringFromCStringBuffer(metadataBuffers[index]),
          content: Self.stringFromCStringBuffer(contentBuffers[index])
        )
      )
    }
    return documents
  }
}

extension CactusIndex {
  /// Adds a ``Document`` to this index.
  public func add(document: Document) throws {
    try self.add(documents: [document])
  }

  /// Adds multiple ``Document`` instances to this index.
  public func add(documents: [Document]) throws {
    try self.validateEmbeddingDimensions(documents.map(\.embedding))
    let result = self.withDocumentFieldPointers(documents) {
      ids,
      contentPointers,
      metadataPointers,
      embeddingPointers in
      cactus_index_add(
        self.indexPointer,
        ids,
        contentPointers,
        metadataPointers,
        embeddingPointers,
        documents.count,
        self.embeddingDimensions
      )
    }
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
  }
}

extension CactusIndex {
  /// Removes a ``Document`` from this index by its id.
  public func deleteDocument(withId id: Document.ID) throws {
    try self.deleteDocuments(withIds: [id])
  }

  /// Removes multiple ``Document`` instances from this index by the specified ids.
  public func deleteDocuments(withIds ids: [Document.ID]) throws {
    let result = ids.withUnsafeBufferPointer {
      cactus_index_delete(self.indexPointer, $0.baseAddress, $0.count)
    }
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
  }
}

// MARK: - Query

extension CactusIndex {
  /// A query for retrieving similar documents.
  public struct Query: Sendable {
    /// The embeddings to compare against.
    public var embeddings: [Float]

    /// The maximum number of similar documents to retrieve.
    public var topK: Int

    /// The minimum similarity score threshold for similar documents.
    public var scoreThreshold: Float

    /// Creates a query.
    ///
    /// - Parameters:
    ///   - embeddings: The embeddings to compare against.
    ///   - topK: The maximum number of similar documents to retrieve.
    ///   - scoreThreshold: The minimum similarity score threshold for similar documents.
    public init(embeddings: [Float], topK: Int = 10, scoreThreshold: Float = Float(-1.0)) {
      self.embeddings = embeddings
      self.topK = topK
      self.scoreThreshold = scoreThreshold
    }
  }

  /// Runs the specified ``Query`` and returns the results.
  public func query(_ query: Query) throws -> [Query.Result] {
    try self.query([query])[0]
  }

  /// Runs the specified ``Query`` instances and returns the results.
  ///
  /// - Returns: An array of arrays of ``Query/Result`` instances, in the same order as the queries.
  public func query(_ queries: [Query]) throws -> [[Query.Result]] {
    guard !queries.isEmpty else { return [] }
    var indexedBatches = [FFIOptions: [(index: Int, query: Query)]]()
    for (index, query) in queries.enumerated() {
      indexedBatches[FFIOptions(query: query), default: []].append((index: index, query: query))
    }

    var results = Array(repeating: [Query.Result](), count: queries.count)
    for (option, batch) in indexedBatches {
      let optionsJSON = String(decoding: try ffiEncoder.encode(option), as: UTF8.self)
      let embeddings = batch.map(\.query.embeddings)
      try self.validateEmbeddingDimensions(embeddings)

      var idBufferSizes = Array(repeating: option.topK, count: batch.count)
      var scoreBufferSizes = Array(repeating: option.topK, count: batch.count)
      let resultCapacity = max(1, option.topK)
      var idBuffers = Array(
        repeating: [Int32](repeating: 0, count: resultCapacity),
        count: batch.count
      )
      var scoreBuffers = Array(
        repeating: [Float](repeating: .zero, count: resultCapacity),
        count: batch.count
      )

      let result = self.withEmbeddingPointers(embeddings) { embeddingPointers in
        self.withMutableBufferPointers(&idBuffers) { idPointers in
          self.withMutableBufferPointers(&scoreBuffers) { scorePointers in
            return idBufferSizes.withUnsafeMutableBufferPointer { idSizePtr in
              scoreBufferSizes.withUnsafeMutableBufferPointer { scoreSizePtr in
                cactus_index_query(
                  self.indexPointer,
                  embeddingPointers,
                  batch.count,
                  self.embeddingDimensions,
                  optionsJSON,
                  idPointers,
                  idSizePtr.baseAddress,
                  scorePointers,
                  scoreSizePtr.baseAddress
                )
              }
            }
          }
        }
      }
      guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
      for (offset, entry) in batch.enumerated() {
        let count = min(idBufferSizes[offset], scoreBufferSizes[offset], resultCapacity)
        guard count > 0 else {
          results[entry.index] = []
          continue
        }

        let ids = idBuffers[offset].prefix(count)
        let scores = scoreBuffers[offset].prefix(count)
        results[entry.index] = zip(ids, scores).map { Query.Result(documentId: $0, score: $1) }
      }
    }
    return results
  }
}

extension CactusIndex.Query {
  /// An individual document result of a query for matching similar documents.
  public struct Result: Sendable {
    /// The id of the document.
    public let documentId: CactusIndex.Document.ID

    /// The similarity score of the document relative to the query.
    public let score: Float
  }
}

extension CactusIndex {
  private struct FFIOptions: Hashable, Sendable, Codable {
    var topK: Int
    var scoreThreshold: Float

    init(query: Query) {
      self.topK = query.topK
      self.scoreThreshold = query.scoreThreshold
    }

    private enum CodingKeys: String, CodingKey {
      case topK = "top_k"
      case scoreThreshold = "score_threshold"
    }
  }

  private static func embeddingElementCount(from rawSize: Int, embeddingDimensions: Int) -> Int {
    let normalizedSize = max(0, rawSize)
    if normalizedSize > embeddingDimensions && normalizedSize % MemoryLayout<Float>.stride == 0 {
      return normalizedSize / MemoryLayout<Float>.stride
    }
    return normalizedSize
  }

  private static func stringFromCStringBuffer(_ buffer: [CChar]) -> String {
    buffer.withUnsafeBufferPointer { pointer in
      guard let baseAddress = pointer.baseAddress else { return "" }
      let nullTerminatorIndex = pointer.firstIndex(of: 0) ?? pointer.count
      let rawBuffer = UnsafeRawBufferPointer(start: baseAddress, count: nullTerminatorIndex)
      return String(decoding: rawBuffer, as: UTF8.self)
    }
  }

  private func validateEmbeddingDimensions(_ embeddings: [[Float]]) throws {
    guard let mismatch = embeddings.first(where: { $0.count != self.embeddingDimensions }) else {
      return
    }
    throw CactusIndexError(
      message:
        "Embedding dimension mismatch. Expected \(self.embeddingDimensions), got \(mismatch.count)."
    )
  }

  private func withDocumentFieldPointers<Result>(
    _ documents: [Document],
    _ body: (
      UnsafePointer<Document.ID>?,
      UnsafeMutablePointer<UnsafePointer<CChar>?>?,
      UnsafeMutablePointer<UnsafePointer<CChar>?>?,
      UnsafeMutablePointer<UnsafePointer<Float>?>?
    ) throws -> Result
  ) rethrows -> Result {
    let ids = documents.map(\.id)
    let contents = documents.map(\.content)
    let metadata = documents.map(\.metadata)
    let embeddings = documents.map(\.embedding)

    return try ids.withUnsafeBufferPointer { idPtr in
      try self.withCStringPointers(contents) { contentPointers in
        try self.withCStringPointers(metadata) { metadataPointers in
          try self.withEmbeddingPointers(embeddings) { embeddingPointers in
            try body(
              idPtr.baseAddress,
              contentPointers,
              metadataPointers,
              embeddingPointers
            )
          }
        }
      }
    }
  }

  private func withCStringPointers<Result>(
    _ strings: [String],
    _ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) throws -> Result
  ) rethrows -> Result {
    try withUnsafeTemporaryAllocation(of: UnsafePointer<CChar>?.self, capacity: strings.count) {
      pointers in
      guard let base = pointers.baseAddress else { return try body(nil) }
      return try self.withCStringPointers(strings, index: 0, pointers: base, body)
    }
  }

  private func withCStringPointers<Result>(
    _ strings: [String],
    index: Int,
    pointers: UnsafeMutablePointer<UnsafePointer<CChar>?>,
    _ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) throws -> Result
  ) rethrows -> Result {
    guard index < strings.count else { return try body(pointers) }
    return try strings[index]
      .withCString { cString in
        pointers[index] = cString
        return try self.withCStringPointers(strings, index: index + 1, pointers: pointers, body)
      }
  }

  private func withEmbeddingPointers<Result>(
    _ embeddings: [[Float]],
    _ body: (UnsafeMutablePointer<UnsafePointer<Float>?>?) throws -> Result
  ) rethrows -> Result {
    try withUnsafeTemporaryAllocation(of: UnsafePointer<Float>?.self, capacity: embeddings.count) {
      pointers in
      guard let base = pointers.baseAddress else { return try body(nil) }
      return try self.withEmbeddingPointers(embeddings, index: 0, pointers: base, body)
    }
  }

  private func withEmbeddingPointers<Result>(
    _ embeddings: [[Float]],
    index: Int,
    pointers: UnsafeMutablePointer<UnsafePointer<Float>?>,
    _ body: (UnsafeMutablePointer<UnsafePointer<Float>?>?) throws -> Result
  ) rethrows -> Result {
    guard index < embeddings.count else { return try body(pointers) }
    return try embeddings[index]
      .withUnsafeBufferPointer { embeddingBuffer in
        pointers[index] = embeddingBuffer.baseAddress
        return try self.withEmbeddingPointers(
          embeddings,
          index: index + 1,
          pointers: pointers,
          body
        )
      }
  }

  private func withMutableBufferPointers<Element, Result>(
    _ buffers: inout [[Element]],
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<Element>?>?) throws -> Result
  ) rethrows -> Result {
    try buffers.withUnsafeMutableBufferPointer { storage in
      try withUnsafeTemporaryAllocation(
        of: UnsafeMutablePointer<Element>?.self,
        capacity: storage.count
      ) { pointers in
        guard let base = pointers.baseAddress else { return try body(nil) }
        return try self.withMutableBufferPointers(storage, index: 0, pointers: base, body)
      }
    }
  }

  private func withMutableBufferPointers<Element, Result>(
    _ buffers: UnsafeMutableBufferPointer<[Element]>,
    index: Int,
    pointers: UnsafeMutablePointer<UnsafeMutablePointer<Element>?>,
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<Element>?>?) throws -> Result
  ) rethrows -> Result {
    guard index < buffers.count else { return try body(pointers) }
    return try buffers[index]
      .withUnsafeMutableBufferPointer { buffer in
        pointers[index] = buffer.baseAddress
        return try self.withMutableBufferPointers(
          buffers,
          index: index + 1,
          pointers: pointers,
          body
        )
      }
  }
}

// MARK: - Compact

extension CactusIndex {
  /// Compacts this index.
  public func compact() throws {
    let result = cactus_index_compact(self.indexPointer)
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
  }
}

// MARK: - Error

public struct CactusIndexError: Error {
  public let message: String?

  fileprivate static func lastErrorMessage() -> Self {
    Self(message: cactus_get_last_error().map { String(cString: $0) })
  }
}
