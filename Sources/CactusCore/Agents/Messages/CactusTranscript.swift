import OrderedCollections

// MARK: - CactusTranscript

public struct CactusTranscript: Hashable, Sendable, Codable {
  private var elements = OrderedDictionary<CactusMessageID, Element>()

  private init(_elements: OrderedDictionary<CactusMessageID, CactusTranscript.Element>) {
    self.elements = _elements
  }

  public init(elements: some Sequence<Element> = []) {
    for element in elements {
      self.elements[element.id] = element
    }
  }

  public subscript(id id: CactusMessageID) -> Element? {
    _read { yield self.elements[id] }
    _modify { yield &self.elements[id] }
  }
}

// MARK: - Element

extension CactusTranscript {
  public struct Element: Hashable, Sendable, Codable, Identifiable {
    public let id: CactusMessageID
    public var message: CactusLanguageModel.ChatMessage
    public var functionCalls: [CactusLanguageModel.FunctionCall]

    public init(
      id: CactusMessageID,
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

extension CactusTranscript {
  @discardableResult
  public mutating func removeElement(id: CactusMessageID) -> Element? {
    self.elements.removeValue(forKey: id)
  }

  @discardableResult
  public mutating func removeElement(at index: Int) -> Element {
    self.elements.remove(at: index).value
  }

  public mutating func removeAll(keepingCapacity: Bool = false) {
    self.elements.removeAll(keepingCapacity: keepingCapacity)
  }

  public mutating func removeAll<E: Error>(where predicate: (Element) throws(E) -> Bool) throws(E) {
    do {
      try self.elements.removeAll { (_, value) in try predicate(value) }
    } catch {
      throw error as! E
    }
  }

  @discardableResult
  public mutating func removeFirst() -> Element {
    self.elements.removeFirst().value
  }

  public mutating func removeFirst(_ n: Int) {
    self.elements.removeFirst(n)
  }

  @discardableResult
  public mutating func removeLast() -> Element {
    self.elements.removeLast().value
  }

  public mutating func removeLast(_ n: Int) {
    self.elements.removeLast(n)
  }

  public mutating func removeSubrange(_ range: some RangeExpression<Int>) {
    self.elements.removeSubrange(range)
  }

  public func filter<E: Error>(_ isIncluded: (Element) throws(E) -> Bool) throws(E) -> Self {
    do {
      return try Self(_elements: self.elements.filter { (_, value) in try isIncluded(value) })
    } catch {
      throw error as! E
    }
  }
}
