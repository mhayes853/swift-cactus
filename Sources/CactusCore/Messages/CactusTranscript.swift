import Foundation

// MARK: - CactusTranscript

/// An ordered collection of transcript elements.
///
/// `CactusTranscript` maintains the order of elements while also providing efficient
/// access by ``CactusMessageID``. It conforms to `MutableCollection` and
/// `RandomAccessCollection` for standard collection operations.
///
/// ```swift
/// var transcript = CactusTranscript()
/// transcript.append(CactusTranscript.Element(message: .system("You are helpful")))
/// transcript.append(CactusTranscript.Element(message: .user("Hello")))
///
/// // Access by index
/// print(transcript[0].message.content) // "You are helpful"
///
/// // Access by ID
/// if let element = transcript[id: someID] {
///   print(element.message.content)
/// }
///
/// // Filter by role
/// let userMessages = transcript.filter(byRole: .user)
/// ```
public struct CactusTranscript: Hashable, Sendable {
  private var elements = [Element]()
  private var messageIndicies = [CactusMessageID: Int]()

  /// Creates a new transcript with the given elements.
  ///
  /// - Parameter elements: A sequence of ``Element`` instances to initialize the transcript with.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public init(elements: some Sequence<Element> = []) {
    for element in elements {
      self.elements.append(element)
      self.messageIndicies[element.id] = self.elements.count - 1
    }
  }

  /// A Boolean value indicating whether the transcript is empty.
  public var isEmpty: Bool {
    self.elements.isEmpty
  }

  /// The number of elements in the transcript.
  public var count: Int {
    self.elements.count
  }

  /// An array of all messages in the transcript, in order.
  ///
  /// Use this property to extract just the ``CactusLanguageModel/ChatMessage`` instances
  /// for passing to inference APIs.
  ///
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public var messages: [CactusLanguageModel.ChatMessage] {
    self.elements.map(\.message)
  }

  /// Accesses the element with the given identifier.
  ///
  /// - Parameter id: The ``CactusMessageID`` to look up.
  /// - Returns: The element with the given identifier, or `nil` if no such element exists.
  /// - Complexity: O(1).
  public subscript(id id: CactusMessageID) -> Element? {
    _read {
      guard let index = self.messageIndicies[id] else {
        yield nil
        return
      }
      yield self.elements[index]
    }
  }

  /// Appends an element to the transcript.
  ///
  /// - Parameter element: The element to append.
  /// - Complexity: O(1) amortized.
  public mutating func append(_ element: Element) {
    self.messageIndicies[element.id] = self.elements.count
    self.elements.append(element)
  }

  /// Appends the elements of a sequence to the transcript.
  ///
  /// - Parameter newElements: A sequence of elements to append.
  /// - Complexity: O(*n*) where *n* is the number of elements in `newElements`.
  public mutating func append(contentsOf newElements: some Sequence<Element>) {
    for element in newElements {
      self.append(element)
    }
  }

  /// Reserves storage for the specified number of elements.
  ///
  /// Call this method before appending a known number of elements to avoid
  /// intermediate reallocations.
  ///
  /// - Parameter capacity: The minimum number of elements to reserve storage for.
  /// - Complexity: O(*n*) where *n* is the new capacity.
  public mutating func reserveCapacity(_ capacity: Int) {
    self.elements.reserveCapacity(capacity)
    self.messageIndicies.reserveCapacity(capacity)
  }

  /// Removes the element with the given identifier.
  ///
  /// - Parameter id: The ``CactusMessageID`` of the element to remove.
  /// - Returns: The removed element, or `nil` if no element with the given identifier exists.
  /// - Complexity: O(*n*) where *n* is the number of elements after the removed element.
  @discardableResult
  public mutating func removeElement(id: CactusMessageID) -> Element? {
    guard let index = self.messageIndicies[id] else { return nil }
    return self.removeElement(at: index)
  }

  /// Removes the element at the given position.
  ///
  /// - Parameter index: The position of the element to remove.
  /// - Returns: The removed element.
  /// - Complexity: O(*n*) where *n* is the number of elements after `index`.
  @discardableResult
  public mutating func removeElement(at index: Int) -> Element {
    let removed = self.elements.remove(at: index)
    self.messageIndicies.removeValue(forKey: removed.id)
    for i in index..<self.elements.count {
      self.messageIndicies[self.elements[i].id] = i
    }
    return removed
  }

  /// Removes all elements from the transcript.
  ///
  /// - Parameter keepingCapacity: If `true`, the transcript's storage capacity is preserved.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public mutating func removeAll(keepingCapacity: Bool = false) {
    self.elements.removeAll(keepingCapacity: keepingCapacity)
    self.messageIndicies.removeAll(keepingCapacity: keepingCapacity)
  }

  /// Removes all elements that satisfy the given predicate.
  ///
  /// - Parameter predicate: A closure that takes an element and returns a Boolean value
  ///   indicating whether the element should be removed.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public mutating func removeAll<E: Error>(where predicate: (Element) throws(E) -> Bool) throws(E) {
    var i = 0
    while i < self.elements.count {
      if try predicate(self.elements[i]) {
        let removed = self.elements.remove(at: i)
        self.messageIndicies.removeValue(forKey: removed.id)
        for j in i..<self.elements.count {
          self.messageIndicies[self.elements[j].id] = j
        }
      } else {
        i += 1
      }
    }
  }

  /// Returns a new transcript containing only elements whose message has the given role.
  ///
  /// - Parameter role: The ``CactusLanguageModel/MessageRole`` to filter by.
  /// - Returns: A new transcript containing only matching elements.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public func filter(byRole role: CactusLanguageModel.MessageRole) -> Self {
    Self(elements: self.elements.filter { $0.message.role == role })
  }

  /// Returns the first element whose message has the given role.
  ///
  /// - Parameter role: The ``CactusLanguageModel/MessageRole`` to search for.
  /// - Returns: The first matching element, or `nil` if no such element exists.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public func firstMessage(forRole role: CactusLanguageModel.MessageRole) -> Element? {
    self.elements.first { $0.message.role == role }
  }

  /// Returns the last element whose message has the given role.
  ///
  /// - Parameter role: The ``CactusLanguageModel/MessageRole`` to search for.
  /// - Returns: The last matching element, or `nil` if no such element exists.
  /// - Complexity: O(*n*) where *n* is the number of elements.
  public func lastMessage(forRole role: CactusLanguageModel.MessageRole) -> Element? {
    self.elements.last { $0.message.role == role }
  }
}

// MARK: - Collection Methods

extension CactusTranscript: MutableCollection {
  public var startIndex: Int { self.elements.startIndex }
  public var endIndex: Int { self.elements.endIndex }

  /// Accesses the element at the specified position.
  ///
  /// When modifying an element, if the new element has a different identifier than the
  /// original, the internal index is updated to reflect the change.
  ///
  /// - Parameter position: The position of the element to access.
  /// - Complexity: O(1) for reading, O(1) for writing when the identifier is unchanged,
  ///   O(*n*) when the identifier changes where *n* is the number of elements after `position`.
  /// - Precondition: The new element's identifier must not already exist at a different position.
  public subscript(position: Int) -> Element {
    _read { yield self.elements[position] }
    _modify {
      let oldID = self.elements[position].id
      yield &self.elements[position]
      let newID = self.elements[position].id
      if oldID != newID {
        if let existingIndex = self.messageIndicies[newID], existingIndex != position {
          preconditionFailure("Duplicate message ID: \(newID) already exists at index \(existingIndex)")
        }
        self.messageIndicies.removeValue(forKey: oldID)
        self.messageIndicies[newID] = position
      }
    }
  }

  public func index(after i: Int) -> Int {
    self.elements.index(after: i)
  }
}

extension CactusTranscript: RandomAccessCollection {}

// MARK: - Element

extension CactusTranscript {
  /// An element in a transcript, containing a message and its unique identifier.
  public struct Element: Hashable, Sendable, Codable, Identifiable {
    /// The unique identifier for this element.
    public let id: CactusMessageID

    /// The chat message.
    public var message: CactusLanguageModel.ChatMessage

    /// Creates a new transcript element.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for this element. Defaults to a new random identifier.
    ///   - message: The chat message.
    public init(
      id: CactusMessageID = CactusMessageID(),
      message: CactusLanguageModel.ChatMessage
    ) {
      self.id = id
      self.message = message
    }
  }
}

// MARK: - Codable

extension CactusTranscript: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.elements = try container.decode([Element].self)
    for (index, element) in self.elements.enumerated() {
      self.messageIndicies[element.id] = index
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.elements)
  }
}
