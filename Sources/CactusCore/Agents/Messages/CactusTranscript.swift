// MARK: - CactusTranscript

public struct CactusTranscript: Hashable, Sendable, Codable {
  private var entries = [Element]()

  public init() {}
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
    _read { yield self.entries[position] }
    _modify { yield &self.entries[position] }
  }

  public var startIndex: Int { self.entries.startIndex }
  public var endIndex: Int { self.entries.endIndex }

  public func index(after i: Int) -> Int {
    self.entries.index(after: i)
  }
}

extension CactusTranscript: RandomAccessCollection {}

extension CactusTranscript: RangeReplaceableCollection {
  public mutating func replaceSubrange<C: Collection<Element>>(
    _ subrange: Range<Int>,
    with newElements: C
  ) {
    self.entries.replaceSubrange(subrange, with: newElements)
  }
}
