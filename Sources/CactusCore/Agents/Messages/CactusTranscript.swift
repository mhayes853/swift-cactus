import OrderedCollections

// MARK: - CactusTranscript

public struct CactusTranscript: Hashable, Sendable, Codable {
  private var elements = OrderedDictionary<CactusGenerationID, Element>()

  public init(elements: some Sequence<Element> = []) {
    for element in elements {
      self.elements[element.id] = element
    }
  }

  public subscript(id id: CactusGenerationID) -> Element? {
    _read { yield self.elements[id] }
    _modify { yield &self.elements[id] }
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
      functionCalls: [CactusLanguageModel.FunctionCall] = []
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
    _read { yield self.elements.values[position] }
    _modify { yield &self.elements.values[position] }
  }

  public var startIndex: Int { self.elements.values.startIndex }
  public var endIndex: Int { self.elements.values.endIndex }

  public func index(after i: Int) -> Int {
    self.elements.values.index(after: i)
  }
}

extension CactusTranscript: RandomAccessCollection {}
