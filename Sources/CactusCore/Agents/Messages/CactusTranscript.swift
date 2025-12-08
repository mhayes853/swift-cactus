import OrderedCollections

// MARK: - CactusTranscript

public struct CactusTranscript: Hashable, Sendable, Codable {
  private var entries = OrderedDictionary<CactusGenerationID, Element>()

  public init() {}

  public subscript(id id: CactusGenerationID) -> Element? {
    _read { yield self.entries[id] }
    _modify { yield &self.entries[id] }
  }
}

// MARK: - Element

extension CactusTranscript {
  public struct Element: Hashable, Sendable, Codable, Identifiable {
    public let id: CactusGenerationID
    public var message: CactusLanguageModel.ChatMessage
    public var functionCalls: [CactusLanguageModel.FunctionCall]

    public init(
      id: CactusGenerationID,
      message: CactusLanguageModel.ChatMessage,
      functionCalls: [CactusLanguageModel.FunctionCall]
    ) {
      self.id = id
      self.message = message
      self.functionCalls = functionCalls
    }
  }
}

// MARK: - Collection

extension CactusTranscript: MutableCollection {
  public subscript(position: Int) -> Element {
    _read { yield self.entries.values[position] }
    _modify { yield &self.entries.values[position] }
  }

  public var startIndex: Int { self.entries.values.startIndex }
  public var endIndex: Int { self.entries.values.endIndex }

  public func index(after i: Int) -> Int {
    self.entries.values.index(after: i)
  }
}

extension CactusTranscript: RandomAccessCollection {}
