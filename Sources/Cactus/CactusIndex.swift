import CXXCactusDarwin
import Foundation

// MARK: - CactusIndex

public final class CactusIndex {
  public static let maxBufferSize = 65535
  public let index: cactus_index_t
  public let embeddingDimensions: Int

  private let isIndexPointerManaged: Bool

  public convenience init(directory: URL, embeddingDimensions: Int) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let index = cactus_index_init(directory.nativePath, embeddingDimensions)
    guard let index else { throw CactusIndexError.lastErrorMessage() }

    self.init(index: index, embeddingDimensions: embeddingDimensions, isIndexPointerManaged: true)
  }

  public init(
    index: cactus_index_t,
    embeddingDimensions: Int,
    isIndexPointerManaged: Bool = false
  ) {
    self.index = index
    self.embeddingDimensions = embeddingDimensions
    self.isIndexPointerManaged = isIndexPointerManaged
  }

  deinit {
    if self.isIndexPointerManaged {
      cactus_index_destroy(self.index)
    }
  }
}

// MARK: - Document

extension CactusIndex {
  public struct Document: Hashable, Sendable, Identifiable {
    public typealias ID = Int32

    public struct BufferSizes: Hashable, Sendable {
      public var content: Int
      public var metadata: Int

      public init(content: Int, metadata: Int) {
        self.content = content
        self.metadata = metadata
      }
    }

    public let id: ID
    public var embedding: [Float]
    public var metadata: String
    public var content: String

    public init(id: ID, embedding: [Float], metadata: String = "", content: String) {
      self.id = id
      self.embedding = embedding
      self.metadata = metadata
      self.content = content
    }
  }
}

extension CactusIndex {
  public func document(
    withId id: Document.ID,
    bufferSizes: Document.BufferSizes? = nil
  ) throws -> Document {
    try self.documents(withIds: [id], bufferSizes: bufferSizes.map { [$0] })[0]
  }

  public func documents(
    withIds ids: [Document.ID],
    bufferSizes: [Document.BufferSizes]? = nil
  ) throws -> [Document] {
    guard !ids.isEmpty else { return [] }
    if let bufferSizes, bufferSizes.count != ids.count {
      throw CactusIndexError(message: "Buffer sizes must match the number of document IDs.")
    }
    let buffers = DocumentOutputBuffers(
      count: ids.count,
      documentBufferSizes: bufferSizes?.map(\.content),
      metadataBufferSizes: bufferSizes?.map(\.metadata),
      embeddingDimensions: self.embeddingDimensions
    )
    let result = ids.withUnsafeBufferPointer { idsPtr in
      cactus_index_get(
        self.index,
        idsPtr.baseAddress,
        ids.count,
        buffers.documentBuffers,
        buffers.documentBufferSizes,
        buffers.metadataBuffers,
        buffers.metadataBufferSizes,
        buffers.embeddingBuffers,
        buffers.embeddingBufferSizes
      )
    }
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
    return try buffers.documents(for: ids, embeddingDimensions: self.embeddingDimensions)
  }

  private struct DocumentOutputBuffers: ~Copyable {
    static let defaultBufferSize = CactusIndex.maxBufferSize

    let count: Int
    let documentBuffers: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let documentBufferSizes: UnsafeMutablePointer<Int>
    let metadataBuffers: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let metadataBufferSizes: UnsafeMutablePointer<Int>
    let embeddingBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>
    let embeddingBufferSizes: UnsafeMutablePointer<Int>

    init(
      count: Int,
      documentBufferSizes: [Int]?,
      metadataBufferSizes: [Int]?,
      embeddingDimensions: Int
    ) {
      if let documentBufferSizes {
        precondition(documentBufferSizes.count == count)
      }
      if let metadataBufferSizes {
        precondition(metadataBufferSizes.count == count)
      }

      self.count = count
      self.documentBuffers = .allocate(capacity: count)
      self.documentBufferSizes = .allocate(capacity: count)
      self.metadataBuffers = .allocate(capacity: count)
      self.metadataBufferSizes = .allocate(capacity: count)
      self.embeddingBuffers = .allocate(capacity: count)
      self.embeddingBufferSizes = .allocate(capacity: count)

      self.documentBuffers.initialize(repeating: nil, count: count)
      self.metadataBuffers.initialize(repeating: nil, count: count)
      self.embeddingBuffers.initialize(repeating: nil, count: count)
      self.documentBufferSizes.initialize(repeating: 0, count: count)
      self.metadataBufferSizes.initialize(repeating: 0, count: count)
      self.embeddingBufferSizes.initialize(repeating: 0, count: count)

      for index in 0..<count {
        let documentSize = max(
          1,
          documentBufferSizes?[index] ?? Self.defaultBufferSize
        )
        let metadataSize = max(
          1,
          metadataBufferSizes?[index] ?? Self.defaultBufferSize
        )
        let embeddingSize = max(1, embeddingDimensions)

        self.documentBuffers[index] = .allocate(capacity: documentSize)
        self.metadataBuffers[index] = .allocate(capacity: metadataSize)
        self.embeddingBuffers[index] = .allocate(capacity: embeddingSize)
        self.documentBufferSizes[index] = documentSize
        self.metadataBufferSizes[index] = metadataSize
        self.embeddingBufferSizes[index] = embeddingSize
      }
    }

    deinit {
      for index in 0..<self.count {
        self.documentBuffers[index]?.deallocate()
        self.metadataBuffers[index]?.deallocate()
        self.embeddingBuffers[index]?.deallocate()
      }
      self.documentBuffers.deinitialize(count: self.count)
      self.documentBufferSizes.deinitialize(count: self.count)
      self.metadataBuffers.deinitialize(count: self.count)
      self.metadataBufferSizes.deinitialize(count: self.count)
      self.embeddingBuffers.deinitialize(count: self.count)
      self.embeddingBufferSizes.deinitialize(count: self.count)
      self.documentBuffers.deallocate()
      self.documentBufferSizes.deallocate()
      self.metadataBuffers.deallocate()
      self.metadataBufferSizes.deallocate()
      self.embeddingBuffers.deallocate()
      self.embeddingBufferSizes.deallocate()
    }

    func documents(
      for ids: [CactusIndex.Document.ID],
      embeddingDimensions: Int
    ) throws -> [CactusIndex.Document] {
      var documents = [CactusIndex.Document]()
      documents.reserveCapacity(self.count)
      for index in 0..<self.count {
        documents.append(
          try self.document(
            for: index,
            ids: ids,
            embeddingDimensions: embeddingDimensions
          )
        )
      }
      return documents
    }

    private func document(
      for index: Int,
      ids: [CactusIndex.Document.ID],
      embeddingDimensions: Int
    ) throws -> CactusIndex.Document {
      let documentSize = self.documentBufferSizes[index]
      guard let documentBuffer = self.documentBuffers[index], documentSize > 0 else {
        throw CactusIndexError(message: "Document buffer was empty.")
      }
      let metadataSize = self.metadataBufferSizes[index]
      guard let metadataBuffer = self.metadataBuffers[index], metadataSize > 0 else {
        throw CactusIndexError(message: "Metadata buffer was empty.")
      }

      let content = String(cString: documentBuffer)
      let metadata = String(cString: metadataBuffer)
      let embedding = self.embeddings(for: index, embeddingDimensions: embeddingDimensions)
      return CactusIndex.Document(
        id: ids[index],
        embedding: embedding,
        metadata: metadata,
        content: content
      )
    }

    private func embeddings(for index: Int, embeddingDimensions: Int) -> [Float] {
      let size = self.embeddingBufferSizes[index]
      guard let embeddingBuffer = self.embeddingBuffers[index], size > 0 else { return [] }
      let count =
        size > embeddingDimensions && size % MemoryLayout<Float>.stride == 0
        ? size / MemoryLayout<Float>.stride
        : size
      return Array(UnsafeBufferPointer(start: embeddingBuffer, count: count))
    }
  }
}

extension CactusIndex {
  public func add(document: Document) throws {
    try self.add(documents: [document])
  }

  public func add(documents: [Document]) throws {
    let fields = try DocumentFieldPointers(documents, embeddingDimensions: self.embeddingDimensions)
    let result = cactus_index_add(
      self.index,
      fields.ids,
      fields.documentPointers,
      fields.metadataPointers,
      fields.embeddingPointers,
      fields.count,
      self.embeddingDimensions
    )
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
  }

  private struct DocumentFieldPointers: ~Copyable {
    let count: Int
    let ids: UnsafeMutablePointer<CactusIndex.Document.ID>
    let documentPointers: UnsafeMutablePointer<UnsafePointer<CChar>?>
    let metadataPointers: UnsafeMutablePointer<UnsafePointer<CChar>?>
    let embeddingPointers: UnsafeMutablePointer<UnsafePointer<Float>?>

    init(_ documents: [CactusIndex.Document], embeddingDimensions: Int) throws {
      self.count = documents.count
      self.ids = .allocate(capacity: documents.count)
      self.documentPointers = .allocate(capacity: documents.count)
      self.metadataPointers = .allocate(capacity: documents.count)
      self.embeddingPointers = .allocate(capacity: documents.count)

      self.ids.initialize(repeating: 0, count: documents.count)
      self.documentPointers.initialize(repeating: nil, count: documents.count)
      self.metadataPointers.initialize(repeating: nil, count: documents.count)
      self.embeddingPointers.initialize(repeating: nil, count: documents.count)

      for (index, document) in documents.enumerated() {
        self.ids[index] = document.id
        self.documentPointers[index] = document.content.withCString { UnsafePointer(strdup($0)) }
        self.metadataPointers[index] = document.metadata.withCString { UnsafePointer(strdup($0)) }

        document.embedding.withUnsafeBufferPointer {
          let ptr = UnsafeMutableBufferPointer<Float>.allocate(capacity: embeddingDimensions)
          memcpy(ptr.baseAddress, $0.baseAddress, embeddingDimensions * MemoryLayout<Float>.stride)
          self.embeddingPointers[index] = UnsafePointer(ptr.baseAddress)
        }
      }
    }

    deinit {
      self.ids.deinitialize(count: self.count)
      self.documentPointers.deinitialize(count: self.count)
      self.metadataPointers.deinitialize(count: self.count)
      self.embeddingPointers.deinitialize(count: self.count)
      self.ids.deallocate()
      self.documentPointers.deallocate()
      self.metadataPointers.deallocate()
      self.embeddingPointers.deallocate()
    }
  }
}

extension CactusIndex {
  public func deleteDocument(withId id: Document.ID) throws {
    try self.deleteDocuments(withIds: [id])
  }

  public func deleteDocuments(withIds ids: [Document.ID]) throws {
    let result = ids.withUnsafeBufferPointer {
      cactus_index_delete(self.index, $0.baseAddress, $0.count)
    }
    guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
  }
}

// MARK: - Query

extension CactusIndex {
  public struct Query: Sendable {
    public var embeddings: [Float]
    public var topK: Int
    public var scoreThreshold: Float

    public init(embeddings: [Float], topK: Int = 10, scoreThreshold: Float = Float(-1.0)) {
      self.embeddings = embeddings
      self.topK = topK
      self.scoreThreshold = scoreThreshold
    }
  }

  public func query(_ query: Query) throws -> [Query.Result] {
    try self.query([query])[0]
  }

  public func query(_ queries: [Query]) throws -> [[Query.Result]] {
    guard !queries.isEmpty else { return [] }
    var indexedBatches = [FFIOptions: [(index: Int, query: Query)]]()
    for (index, query) in queries.enumerated() {
      indexedBatches[FFIOptions(query: query), default: []].append((index: index, query: query))
    }

    var results = Array(repeating: [Query.Result](), count: queries.count)
    for (option, batch) in indexedBatches {
      let optionsJSON = String(decoding: try Self.queryEncoder.encode(option), as: UTF8.self)
      let embeddingPointers = try EmbeddingBatchPointers(
        embeddings: batch.map(\.query.embeddings),
        embeddingDimensions: self.embeddingDimensions
      )
      let buffers = QueryResultBuffers(count: batch.count, topK: option.topK)
      let result = cactus_index_query(
        self.index,
        embeddingPointers.pointers,
        batch.count,
        self.embeddingDimensions,
        optionsJSON,
        buffers.idBuffers,
        buffers.idBufferSizes,
        buffers.scoreBuffers,
        buffers.scoreBufferSizes
      )
      guard result == 0 else { throw CactusIndexError.lastErrorMessage() }
      for (offset, entry) in batch.enumerated() {
        results[entry.index] = buffers.results(at: offset)
      }
    }
    return results
  }
}

extension CactusIndex.Query {
  public struct Result: Sendable {
    public let documentId: CactusIndex.Document.ID
    public let score: Float
  }
}

extension CactusIndex {
  private static let queryEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
  }()

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

  private struct EmbeddingBatchPointers: ~Copyable {
    let count: Int
    let pointers: UnsafeMutablePointer<UnsafePointer<Float>?>

    init(embeddings: [[Float]], embeddingDimensions: Int) throws {
      self.count = embeddings.count
      self.pointers = .allocate(capacity: embeddings.count)
      self.pointers.initialize(repeating: nil, count: embeddings.count)

      for (index, embedding) in embeddings.enumerated() {
        if embeddingDimensions > 0 {
          embedding.withUnsafeBufferPointer { self.pointers[index] = $0.baseAddress }
        }
      }
    }

    deinit {
      self.cleanup()
    }

    private func cleanup() {
      self.pointers.deinitialize(count: self.count)
      self.pointers.deallocate()
    }
  }

  private struct QueryResultBuffers: ~Copyable {
    let count: Int
    let idBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>
    let idBufferSizes: UnsafeMutablePointer<Int>
    let scoreBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>
    let scoreBufferSizes: UnsafeMutablePointer<Int>

    init(count: Int, topK: Int) {
      self.count = count
      self.idBuffers = .allocate(capacity: count)
      self.idBufferSizes = .allocate(capacity: count)
      self.scoreBuffers = .allocate(capacity: count)
      self.scoreBufferSizes = .allocate(capacity: count)

      for i in 0..<count {
        self.idBuffers[i] = .allocate(capacity: topK)
        self.scoreBuffers[i] = .allocate(capacity: topK)
      }
      self.idBufferSizes.initialize(repeating: topK, count: count)
      self.scoreBufferSizes.initialize(repeating: topK, count: count)
    }

    deinit {
      for index in 0..<self.count {
        self.idBuffers[index]?.deallocate()
        self.scoreBuffers[index]?.deallocate()
      }
      self.idBuffers.deinitialize(count: self.count)
      self.idBufferSizes.deinitialize(count: self.count)
      self.scoreBuffers.deinitialize(count: self.count)
      self.scoreBufferSizes.deinitialize(count: self.count)
      self.idBuffers.deallocate()
      self.idBufferSizes.deallocate()
      self.scoreBuffers.deallocate()
      self.scoreBufferSizes.deallocate()
    }

    func results(at index: Int) -> [CactusIndex.Query.Result] {
      let idCount = self.idBufferSizes[index]
      let scoreCount = self.scoreBufferSizes[index]
      let count = min(idCount, scoreCount)
      guard count > 0,
        let idBuffer = self.idBuffers[index],
        let scoreBuffer = self.scoreBuffers[index]
      else { return [] }
      let ids = Array(UnsafeBufferPointer(start: idBuffer, count: count))
      let scores = Array(UnsafeBufferPointer(start: scoreBuffer, count: count))
      return zip(ids, scores).map { CactusIndex.Query.Result(documentId: $0, score: $1) }
    }
  }
}

// MARK: - Compact

extension CactusIndex {
  public func compact() throws {
    let result = cactus_index_compact(self.index)
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
